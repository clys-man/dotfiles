import json
import locale
import sys
import threading
import time

import gi

gi.require_version('GWeather', '4.0')
from gi.repository import Gio, GLib, GWeather


def event_overlaps(event, since, until):
    start, end = event['start'], event['end']
    return since <= start < until if start == end else start < until and end > since


def merge_events(events, records):
    removed = set()
    for record in records:
        uid, summary, start, end = record[:4]
        if not uid.endswith('\n'):
            prefix = uid.rsplit('\n', 1)[0] + '\n'
            if prefix not in removed:
                events = {key: event for key, event in events.items() if not key.startswith(prefix)}
                removed.add(prefix)
        events[uid] = {'id': uid, 'summary': summary, 'start': start, 'end': end}
    return events


def weather_icon(name):
    name = name or ''
    if 'storm' in name:
        return 'weather-storm'
    if 'snow' in name:
        return 'weather-snow'
    if 'shower' in name or 'rain' in name:
        return 'weather-rain'
    if 'fog' in name:
        return 'weather-fog'
    if 'few-clouds' in name:
        return 'weather-partly-cloudy'
    if 'cloud' in name or 'overcast' in name:
        return 'weather-cloudy'
    return 'moon' if 'night' in name else 'sun'


def forecast_data(infos, now):
    result = []
    previous = None
    for info in infos:
        valid_time, timestamp = info.get_value_update()
        valid_temp, temperature = info.get_value_temp(GWeather.TemperatureUnit.DEFAULT)
        if not valid_time or not valid_temp or timestamp < now or previous is not None and timestamp - previous < 3600:
            continue
        result.append({'time': timestamp, 'temperature': round(temperature), 'icon': weather_icon(info.get_symbolic_icon_name())})
        previous = timestamp
        if len(result) == 5:
            break
    return result


class Integration:
    def __init__(self):
        self.loop = GLib.MainLoop()
        self.active = False
        self.since = 0
        self.until = 0
        self.events = {}
        self.calendar_state = 'loading'
        self.has_calendars = False
        self.calendar = None
        self.request_id = 0
        self.weather = {'state': 'loading', 'location': '', 'temperature': '', 'conditions': '', 'forecasts': []}
        self.weather_info = GWeather.Info.new(None)
        self.weather_info.set_application_id('org.gnome.Weather')
        self.weather_info.set_contact_info('https://gitlab.gnome.org/GNOME/gnome-weather')
        self.weather_info.set_enabled_providers(GWeather.Provider.METAR | GWeather.Provider.MET_NO | GWeather.Provider.OWM)
        self.weather_info.connect('updated', self.weather_updated)
        self.last_weather_update = 0
        self.weather_location = None
        self.settings = []
        self.weather_proxy = None
        self.geo = None
        self.geo_starting = False
        for schema in ('org.gnome.Weather', 'org.gnome.shell.weather'):
            if Gio.SettingsSchemaSource.get_default().lookup(schema, True):
                settings = Gio.Settings.new(schema)
                settings.connect('changed::locations', self.location_changed)
                settings.connect('changed::automatic-location', self.location_changed)
                self.settings.append(settings)
        self.load_location()
        Gio.bus_get(Gio.BusType.SESSION, None, self.bus_ready)
        GLib.timeout_add_seconds(60, self.periodic_update)
        threading.Thread(target=self.read_input, daemon=True).start()
        self.emit()

    def emit(self):
        records = [event for event in self.events.values() if event_overlaps(event, self.since, self.until)]
        records.sort(key=lambda event: (event['start'], event['end'], event['id']))
        try:
            print(json.dumps({'calendarState': self.calendar_state, 'hasCalendars': self.has_calendars, 'events': records, 'weather': self.weather}, ensure_ascii=False), flush=True)
        except BrokenPipeError:
            self.loop.quit()

    def read_input(self):
        for line in sys.stdin:
            try:
                request = json.loads(line)
                if isinstance(request, dict):
                    GLib.idle_add(self.request, request)
            except ValueError:
                continue
        GLib.idle_add(self.loop.quit)

    def request(self, request):
        self.active = bool(request.get('active', False))
        try:
            since, until = int(request.get('since', 0)), int(request.get('until', 0))
        except (TypeError, ValueError):
            return GLib.SOURCE_REMOVE
        if not 0 < until - since <= 90 * 86400:
            return GLib.SOURCE_REMOVE
        changed = (since, until) != (self.since, self.until)
        self.since, self.until = since, until
        if self.active:
            if changed or self.calendar_state != 'ready':
                self.load_events()
            self.refresh_weather()
        self.emit()
        return GLib.SOURCE_REMOVE

    def bus_ready(self, source, result):
        try:
            connection = Gio.bus_get_finish(result)
            Gio.DBusProxy.new(connection, Gio.DBusProxyFlags.NONE, None, 'org.gnome.Shell.CalendarServer', '/org/gnome/Shell/CalendarServer', 'org.gnome.Shell.CalendarServer', None, self.calendar_ready)
            Gio.DBusProxy.new(connection, Gio.DBusProxyFlags.DO_NOT_AUTO_START, None, 'org.gnome.Weather', '/org/gnome/Weather', 'org.gnome.Shell.WeatherIntegration', None, self.weather_proxy_ready)
        except GLib.Error:
            self.calendar_state = 'unavailable'
            self.emit()

    def calendar_ready(self, source, result):
        try:
            self.calendar = Gio.DBusProxy.new_finish(result)
            self.calendar.connect('g-signal', self.calendar_signal)
            self.calendar.connect('g-properties-changed', self.calendar_properties)
            self.calendar.connect('notify::g-name-owner', self.calendar_owner)
            self.calendar_properties()
            if self.active:
                self.load_events()
        except GLib.Error:
            self.calendar_state = 'unavailable'
            self.emit()

    def calendar_properties(self, *args):
        value = self.calendar.get_cached_property('HasCalendars')
        self.has_calendars = bool(value.unpack()) if value is not None else False
        self.emit()

    def calendar_owner(self, *args):
        self.events = {}
        self.calendar_state = 'loading' if self.calendar.get_name_owner() else 'unavailable'
        if self.active:
            self.load_events()
        self.emit()

    def load_events(self):
        if self.calendar is None or not self.calendar.get_name_owner():
            return
        self.request_id += 1
        request_id = self.request_id
        self.events = {}
        self.calendar_state = 'loading'
        self.emit()
        self.calendar.call('SetTimeRange', GLib.Variant('(xxb)', (self.since, self.until, True)), Gio.DBusCallFlags.NONE, 15000, None, self.events_requested, request_id)

    def events_requested(self, proxy, result, request_id):
        try:
            proxy.call_finish(result)
            if request_id == self.request_id:
                self.calendar_state = 'ready'
        except GLib.Error:
            if request_id == self.request_id:
                self.calendar_state = 'unavailable'
        self.emit()

    def calendar_signal(self, proxy, sender, signal, parameters):
        values = parameters.unpack()
        if signal == 'EventsAddedOrUpdated':
            self.events = merge_events(self.events, values[0])
        elif signal == 'EventsRemoved':
            prefixes = tuple(values[0])
            self.events = {key: value for key, value in self.events.items() if not key.startswith(prefixes)}
        elif signal == 'ClientDisappeared':
            prefix = values[0] + '\n'
            self.events = {key: value for key, value in self.events.items() if not key.startswith(prefix)}
        self.emit()

    def location_changed(self, *args):
        self.load_location()

    def load_location(self):
        world = GWeather.Location.get_world()
        location = None
        for settings in self.settings:
            locations = settings.get_value('locations')
            if locations.n_children():
                try:
                    location = world.deserialize(locations.get_child_value(0).get_variant())
                except GLib.Error:
                    location = None
                if location:
                    break
        self.set_location(location)
        if location is None and self.active:
            self.start_geolocation()

    def set_location(self, location):
        if location is not None and self.weather_location is not None and location.equal(self.weather_location):
            return
        self.weather_info.abort()
        self.weather_location = location
        self.weather_info.set_location(location)
        name = location.get_name() if location else ''
        if location and location.has_coords():
            city = GWeather.Location.get_world().find_nearest_city(*location.get_coords())
            if city:
                name = city.get_name()
        self.weather = {'state': 'loading' if location else 'no-location', 'location': name or '', 'temperature': '', 'conditions': '', 'forecasts': []}
        self.last_weather_update = 0
        if self.active:
            self.refresh_weather()
        self.emit()

    def weather_proxy_ready(self, source, result):
        try:
            self.weather_proxy = Gio.DBusProxy.new_finish(result)
            self.weather_proxy.connect('g-properties-changed', self.weather_properties)
            self.weather_proxy.connect('notify::g-name-owner', self.weather_properties)
            self.weather_properties()
        except GLib.Error:
            pass

    def weather_properties(self, *args):
        if not self.weather_proxy.get_name_owner():
            return
        locations = self.weather_proxy.get_cached_property('Locations')
        if locations and locations.n_children():
            self.set_location(GWeather.Location.get_world().deserialize(locations.get_child_value(0).get_variant()))

    def start_geolocation(self):
        if self.geo_starting or self.geo is not None or not any(settings.get_boolean('automatic-location') for settings in self.settings):
            return
        try:
            if not Gio.Settings.new('org.gnome.system.location').get_boolean('enabled'):
                return
            gi.require_version('Geoclue', '2.0')
            from gi.repository import Geoclue
            self.geo_starting = True
            Geoclue.Simple.new('org.gnome.Weather', Geoclue.AccuracyLevel.CITY, None, self.geolocation_ready)
        except (ValueError, GLib.Error):
            self.geo_starting = False

    def geolocation_ready(self, source, result):
        from gi.repository import Geoclue
        self.geo_starting = False
        try:
            self.geo = Geoclue.Simple.new_finish(result)
            self.geo.connect('notify::location', self.geolocation_changed)
            self.geolocation_changed()
        except GLib.Error:
            pass

    def geolocation_changed(self, *args):
        location = self.geo.get_location()
        if location:
            self.set_location(GWeather.Location.new_detached('', None, location.get_latitude(), location.get_longitude()))

    def refresh_weather(self):
        if not self.weather_location:
            self.start_geolocation()
            return
        now = time.monotonic()
        if now - self.last_weather_update < 600:
            return
        self.last_weather_update = now
        self.weather['state'] = 'loading'
        self.emit()
        self.weather_info.update()

    def weather_updated(self, info):
        if info.is_valid():
            conditions = info.get_conditions()
            self.weather.update(state='ready', temperature=info.get_temp(), conditions=info.get_sky() if not conditions or conditions == '-' else conditions, icon=weather_icon(info.get_symbolic_icon_name()), forecasts=forecast_data(info.get_forecast_list(), time.time()))
        else:
            self.weather['state'] = 'offline' if info.network_error() else 'unavailable'
        self.emit()

    def periodic_update(self):
        if self.active:
            self.refresh_weather()
            if self.calendar_state == 'unavailable':
                self.load_events()
        return GLib.SOURCE_CONTINUE


if __name__ == '__main__':
    try:
        locale.setlocale(locale.LC_ALL, '')
        locale.setlocale(locale.LC_MESSAGES, 'en_US.UTF-8')
    except locale.Error:
        pass
    Integration().loop.run()
