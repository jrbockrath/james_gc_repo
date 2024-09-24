import json
from unittest import TestCase, main
from cronofy import Calendar, Channel, Event, Profile
import cronofy
import responses

DUMMY_CALENDARS = json.loads(
    '{"calendars":'
    '[{"provider_name":"google",'
    '"profile_name":"someone@somewhere.com",'
    '"calendar_id":"cal_id_1",'
    '"calendar_name":"Calendar 1",'
    '"calendar_readonly":false,'
    '"calendar_deleted":false},'

    '{"provider_name":"google",'
    '"profile_name":"someone@somewhere.com",'
    '"calendar_id":"cal_id_2",'
    '"calendar_name":"CAlendar 2",'
    '"calendar_readonly":false,'
    '"calendar_deleted":false},'

    '{"provider_name":"google",'
    '"profile_name":"someone@somewhere.com",'
    '"calendar_id":"cal_id_3",'
    '"calendar_name":"Calendar 3",'
    '"calendar_readonly":false,'
    '"calendar_deleted":false}]}')


DUMMY_CREATED_CALENDAR = {
  "calendar": {
    "provider_name": "google",
    "profile_id": "pro_n23kjnwrw2",
    "profile_name": "example@cronofy.com",
    "calendar_id": "cal_n23kjnwrw2_sakdnawerd3",
    "calendar_name": "New Calendar",
    "calendar_readonly": False,
    "calendar_deleted": False
  }
}


DUMMY_PROFILES = {
    "profiles": [
        {
          "provider_name": "google",
          "profile_id": "pro_n23kjnwrw2",
          "profile_name": "example@cronofy.com",
          "profile_connected": True
        },
        {
          "provider_name": "apple",
          "profile_id": "pro_n23kjnwrw2",
          "profile_name": "example@cronofy.com",
          "profile_connected": False,
          "profile_relink_url": "http://to.cronofy.com/RaNggYu"
        }
    ]
}

DUMMY_EVENT_CREATE = None

DUMMY_EVENT_DELETE = None

DUMMY_EVENTS_PAGE_1 = json.loads(
                          '{"pages":'
                          '{"current":1,"total":2,"next_page":"https://api.cronofy.com/v1/events/pages/08a07b034306679e"},'
                          ''
                          '"events":'
                          '[{"calendar_id":"cal_U9uuErStTG@EAAAB_IsAsykA2DBTWqQTf-f0kJw",'
                          '"event_uid":"evt_external_54008b1a4a41730f8d5c6037",'
                          '"summary":"Company Retreat",'
                          '"description":"",'
                          '"start":"2014-09-06",'
                          '"end":"2014-09-08",'
                          '"deleted":false},'
                          ''
                          '{"calendar_id": "cal_U9uuErStTG@EAAAB_IsAsykA2DBTWqQTf-f0kJw",'
                          '"event_uid":"evt_external_54008b1a4a41730f8d5c6038",'
                          '"summary":"Dinner with Laura",'
                          '"description":"",'
                          '"start":"2014-09-13T19:00:00Z",'
                          '"end":"2014-09-13T21:00:00Z",'
                          '"deleted":false,'
                          '"location":{"description":"Pizzeria"}}]}')

DUMMY_EVENTS_PAGE_2 = json.loads(
                          '{"pages":'
                          '{"current":2,"total":2},'
                          ''
                          '"events":'
                          '[{"calendar_id":"cal_U9uuErStTG@EAAAB_IsAsykA2DBTWqQTf-f0kJw",'
                          '"event_uid":"evt_external_54008b1a4a41730f8d596037",'
                          '"summary":"Company Retreat 2",'
                          '"description":"",'
                          '"start":"2014-09-07",'
                          '"end":"2014-09-09",'
                          '"deleted":false},'
                          ''
                          '{"calendar_id": "cal_U9uuErStTG@EAAAB_IsAsykA2DBTWqQTf-f0kJw",'
                          '"event_uid":"evt_external_54008b1a4a31730f8d5c6038",'
                          '"summary":"Dinner with Laura 2",'
                          '"description":"",'
                          '"start":"2014-09-14T19:00:00Z",'
                          '"end":"2014-09-14T21:00:00Z",'
                          '"deleted":false,'
                          '"location":{"description":"Pizzeria"}}]}')

DUMMY_CHANNEL_CREATE = json.loads(
                          '{"channel":'
                          '{"channel_id": "chn_54cf7c7cb4ad4c1027000001",'
                          '"callback_url": "https://example.com/api",'
                          '"filters": {}}}')

DUMMY_CHANNEL_DELETE = None

DUMMY_CHANNELS = json.loads(
                          '{"channels":'
                          '[{"channel_id": "chn_54cf7c7cb4ad4c1027000001",'
                          '"callback_url": "https://example.com/api",'
                          '"filters": {}}]}')

DUMMY_OATH_TOKEN = json.loads(
    '{"token_type":"bearer",'
    '"access_token":"P531x88i05Ld2yXHIQ7WjiEyqlmOHsgI",'
    '"expires_in":3600,'
    '"refresh_token":"3gBYG1XamYDUEXUyybbummQWEe5YqPmf",'
    '"scope":"list_calendars create_event delete_event"}'
)


class ResourceTest(TestCase):

    @responses.activate
    def test_calendars_all(self):
        responses.add(responses.GET, 'https://api.cronofy.com/v1/calendars',
                      body=json.dumps(DUMMY_CALENDARS), status=200,
                      content_type='application/json')

        calendars = Calendar.all(access_token="DUMMY", params=None)

        self.assertEqual(3, len(calendars))

    @responses.activate
    def test_calendars_create(self):
        responses.add(responses.POST, 'https://api.cronofy.com/v1/calendars',
                      body=json.dumps(DUMMY_CREATED_CALENDAR), status=200,
                      content_type='application/json')

        params = {"profile_id": "pro_n23kjnwrw2", "name": "New Calendar"}

        calendar = Calendar.create(access_token="DUMMY",
                                    params=params)

        self.assertEqual(calendar.calendar_name, params['name'])
        self.assertEqual(calendar.profile_id, params['profile_id'])

    @responses.activate
    def test_calendars_create_or_update_event(self):

        calendar_id = "cal_n23kjnwrw2_sakdnawerd3"

        responses.add(responses.POST, 'https://api.cronofy.com/v1/calendars/{}/events'.format(calendar_id),
                      body=json.dumps(DUMMY_EVENT_CREATE), status=202,
                      content_type='application/json')

        params = {"blah": "blah"}

        try:
            Calendar.create_or_update_event(object_id=calendar_id, access_token="DUMMY", params=params)
        except cronofy.CronofyError as e:
            self.fail("request raised exception: {}".format(e))

    @responses.activate
    def test_calendars_delete_event(self):

        calendar_id = "cal_n23kjnwrw2_sakdnawerd3"

        responses.add(responses.DELETE, 'https://api.cronofy.com/v1/calendars/{}/events'.format(calendar_id),
                      body=json.dumps(DUMMY_EVENT_DELETE), status=202,
                      content_type='application/json')

        params = {"blah": "blah"}

        try:
            Calendar.delete_event(object_id=calendar_id, access_token="DUMMY", params=params)
        except cronofy.CronofyError as e:
            self.fail("request raised exception: {}".format(e))

    @responses.activate
    def test_channels_all(self):
      responses.add(responses.GET, 'https://api.cronofy.com/v1/channels',
                    body=json.dumps(DUMMY_CHANNELS), status=200,
                    content_type='application/json')

      channels = Channel.all(access_token="DUMMY")

      self.assertEqual(1, len(channels))

    @responses.activate
    def test_channels_create(self):
        responses.add(responses.POST, 'https://api.cronofy.com/v1/channels',
                      body=json.dumps(DUMMY_CHANNEL_CREATE), status=200,
                      content_type='application/json')

        params = {"callback_url": "https://example.com/api"}

        try:
            Channel.create(access_token="DUMMY", params=params)
        except cronofy.CronofyError as e:
            self.fail("request raised exception: {}".format(e))

    @responses.activate
    def test_channels_delete(self):
        channel_id = 'chn_54cf7c7cb4ad4c1027000001'

        responses.add(responses.DELETE, 'https://api.cronofy.com/v1/channels/{}'.format(channel_id),
                      body=json.dumps(DUMMY_CHANNEL_DELETE), status=202,
                      content_type='application/json')

        try:
            Channel.delete(object_id=channel_id, access_token="DUMMY")
        except cronofy.CronofyError as e:
            self.fail("request raised exception: {}".format(e))

    @responses.activate
    def test_events_all(self):
        responses.add(responses.GET, 'https://api.cronofy.com/v1/events',
                      body=json.dumps(DUMMY_EVENTS_PAGE_1), status=200,
                      content_type='application/json')

        events = Event.all(access_token="DUMMY")

        self.assertEqual(2, len(events))

    @responses.activate
    def test_events_all_pages(self):
        responses.add(responses.GET, 'https://api.cronofy.com/v1/events',
                      body=json.dumps(DUMMY_EVENTS_PAGE_1), status=200,
                      content_type='application/json')
        responses.add(responses.GET, 'https://api.cronofy.com/v1/events/pages/08a07b034306679e',
              body=json.dumps(DUMMY_EVENTS_PAGE_2), status=200,
              content_type='application/json')

        events = Event.all(access_token="DUMMY").get_all_pages()

        print events

        self.assertEqual(4, len(events))

    @responses.activate
    def test_token_acquire(self):
        responses.add(responses.POST, 'https://api.cronofy.com/oauth/token',
                      body=json.dumps(DUMMY_OATH_TOKEN), status=200,
                      content_type='application/json')

        token = cronofy.Token.acquire(code="DUMMY_CODE", original_redirect_uri="http://DUMMY_REDIRECT")

        self.assertEqual(token.access_token, "P531x88i05Ld2yXHIQ7WjiEyqlmOHsgI")

    @responses.activate
    def test_profiles_all(self):
        responses.add(responses.GET, 'https://api.cronofy.com/v1/profiles',
                      body=json.dumps(DUMMY_PROFILES), status=200,
                      content_type='application/json')

        calendars = Profile.all(access_token="DUMMY", params=None)

        self.assertEqual(2, len(calendars))

if __name__ == '__main__':
    main()
