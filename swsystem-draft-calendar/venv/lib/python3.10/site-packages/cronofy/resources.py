import json
import sys
import urllib
import cronofy
import requests


PYTHON_CLASS_NAME_TO_API_NAME = {
    'Calendar': 'calendar', 'Event': 'event', 'Token': 'token', 'FreeBusy': 'free_busy', 'Profile': 'profile', 'Channel': 'channel'}

def convert_to_cronofy_object(resp, type):
    types = {'calendar': Calendar, 'event': Event, 'token': Token, 'free_busy': FreeBusy}

    if isinstance(resp, list):
        return [convert_to_cronofy_object(i,type) for i in resp]
    elif isinstance(resp, dict) and not isinstance(resp, CronofyObject):
        resp = resp.copy()
        klass_name = type
        if isinstance(klass_name, basestring):
            klass = types.get(klass_name, CronofyObject)
        else:
            klass = CronofyObject
        return klass.construct_from(resp)
    else:
        return resp

class CronofyObject(dict):
    def __init__(self, client_id=None, client_secret=None, **params):
        super(CronofyObject, self).__init__()

        object.__setattr__(self, 'client_id', client_id)
        object.__setattr__(self, 'client_secret', client_secret)

    def __setattr__(self, k, v):
        if k[0] == '_' or k in self.__dict__:
            return super(CronofyObject, self).__setattr__(k, v)
        else:
            self[k] = v

    def __getattr__(self, k):
        if k[0] == '_':
            raise AttributeError(k)

        try:
            return self[k]
        except KeyError, err:
            raise AttributeError(*err.args)

    def __setitem__(self, k, v):
        if v == "":
            raise ValueError(
                "You cannot set %s to an empty string. "
                "We interpret empty strings as None in requests."
                "You may set %s.%s = None to delete the property" % (
                    k, str(self), k))

        super(CronofyObject, self).__setitem__(k, v)

        # Allows for unpickling in Python 3.x
        if not hasattr(self, '_unsaved_values'):
            self._unsaved_values = set()

        self._unsaved_values.add(k)

    def __getitem__(self, k):
        return super(CronofyObject, self).__getitem__(k)


    def __delitem__(self, k):
        raise TypeError(
            "You cannot delete attributes on a CronofyObject. "
            "To unset a property, set it to None.")

    def request(self, method, url, params=None, headers=None):
        if params is None:
            params = self._retrieve_params

        #TODO: do the request

        return {}

    @classmethod
    def construct_from(cls, values):
        instance = cls(values.get('id'))
        instance.refresh_from(values)
        return instance

    def refresh_from(self, values):
        for k, v in values.iteritems():
            super(CronofyObject, self).__setitem__(
                k, convert_to_cronofy_object(v, k))

    def __repr__(self):
        ident_parts = [type(self).__name__]

        if isinstance(self.get('object'), basestring):
            ident_parts.append(self.get('object'))

        if isinstance(self.get('id'), basestring):
            ident_parts.append('id=%s' % (self.get('id'),))

        unicode_repr = '<%s at %s> JSON: %s' % (
            ' '.join(ident_parts), hex(id(self)), str(self))

        if sys.version_info[0] < 3:
            return unicode_repr.encode('utf-8')
        else:
            return unicode_repr

    def __str__(self):
        return json.dumps(self, sort_keys=True, indent=2)


class APIResource(CronofyObject):

    @classmethod
    def class_name(cls):
        if cls == APIResource:
            raise NotImplementedError(
                'APIResource is an abstract class.  You should perform '
                'actions on its subclasses')
        try:
            return str(urllib.quote_plus(PYTHON_CLASS_NAME_TO_API_NAME[cls.__name__]))
        except KeyError:
            raise RuntimeError("We are not expecting a class called cls.__name__. "
                               "Maybe add it to PYTHON_CLASS_NAME_TO_API_NAME?")

    @classmethod
    def class_name_for_url(cls):
        cls_name = cls.class_name()
        return "%ss" % cls_name.lower()

class Account(APIResource):

    @classmethod
    def fetch(cls, access_token):
        response = requests.get("%s/v1/%s" % (cronofy.api_base, cls.class_name(),),
                                headers={'content-type': 'application/json', 'authorization': 'Bearer %s' % access_token})

        if response.status_code == requests.codes.ok:
            items = response.json()["%s" % cls.class_name().lower()]

            #TODO: add the following of pagination?
            return convert_to_cronofy_object(items, cls.class_name().lower())
        else:
            #TODO: wrap HTTP errors and throw our own
            raise CronofyError("Something is wrong", response.text, response.status_code)



class OauthAPIResource(APIResource):

    @classmethod
    def class_url(cls):
        cls_name = cls.class_name()
        return "/oauth/%s" % (cls_name,)

class Token(OauthAPIResource):

    @classmethod
    def _post_request(cls, post_data):
        post_data["client_id"] = cronofy.client_id
        post_data["client_secret"] = cronofy.client_secret

        response = requests.post("%s%s" % (cronofy.api_base, cls.class_url(),),
                                 data=json.dumps(post_data),
                                 headers={'content-type': 'application/json'})
        if response.status_code == requests.codes.ok:
            item = response.json()
            return convert_to_cronofy_object(item, cls.class_name().lower())
        else:
            # TODO: wrap HTTP errors and throw our own
            raise CronofyError("Something is wrong", response.text, response.status_code)

    @classmethod
    def acquire(cls, code, original_redirect_uri):
        post_data = {'code': code, 'redirect_uri': original_redirect_uri,'grant_type': 'authorization_code'}
        return cls._post_request(post_data)

    @classmethod
    def refresh(cls, refresh_token):
        post_data = {'refresh_token' : refresh_token,'grant_type': 'refresh_token'}
        return cls._post_request(post_data)


class DeleteSubEventAPIResourceMixin(APIResource):

    @classmethod
    def delete_event(cls, object_id, access_token, params):
        """
        Delete an event for this object (almost certainly a calendar)

        :param object_id:
        :param access_token:
        :param params:
        :return:
        """

        object_id = object_id.strip('/')

        response = requests.delete("{}{}/{}/events".format(cronofy.api_base, cls.class_url(), object_id),
                                json=params,
                                headers={'content-type': 'application/json',
                                         'authorization': 'Bearer %s' % access_token})

        if response.status_code in [requests.codes.ok, requests.codes.created, requests.codes.accepted]:

            return

        else:
            #TODO: wrap HTTP errors and throw our own
            raise CronofyError("Something is wrong", response.text, response.status_code)


class CreateAPIResourceMixin(APIResource):

    @classmethod
    def create(cls, access_token, params):
        """
        Create an object
        :param access_token:
        :param params:
        :return:
        """

        response = requests.post("%s%s" % (cronofy.api_base, cls.class_url(),),
                                json=params,
                                headers={'content-type': 'application/json',
                                         'authorization': 'Bearer %s' % access_token})
        if response.status_code == requests.codes.ok:

            response_json = response.json()
            item = response_json[cls.class_name()]

            result = convert_to_cronofy_object(item, cls.class_name().lower())

            return result

        else:
            #TODO: wrap HTTP errors and throw our own
            raise CronofyError("Something is wrong", response.text, response.status_code)


class CreateSubEventAPIResourceMixin(APIResource):
    """
    Happy to admit that this is rather a specific mixin. But I'd rather keep the structure.
    """

    @classmethod
    def create_or_update_event(cls, object_id, access_token, params):
        """
        Create an event for this object (almost certainly a calendar)

        :param object_id:
        :param access_token:
        :param params:
        :return:
        """

        object_id = object_id.strip('/')

        response = requests.post("{}{}/{}/events".format(cronofy.api_base, cls.class_url(), object_id),
                                json=params,
                                headers={'content-type': 'application/json',
                                         'authorization': 'Bearer %s' % access_token})

        if response.status_code in [requests.codes.ok, requests.codes.created, requests.codes.accepted]:

            return

        else:
            #TODO: wrap HTTP errors and throw our own
            raise CronofyError("Something is wrong", response.text, response.status_code)


class DeleteAPIResourceMixin(APIResource):

    @classmethod
    def delete(cls, object_id, access_token):
        """
        Delete this object

        :param object_id:
        :param access_token:
        :return:
        """
        object_id = object_id.strip('/')

        response = requests.delete("{}{}/{}".format(cronofy.api_base, cls.class_url(), object_id),
                                headers={'content-type': 'application/json',
                                         'authorization': 'Bearer %s' % access_token})
        if response.status_code in [requests.codes.ok, requests.codes.created, requests.codes.accepted]:
            return

        else:
            #TODO: wrap HTTP errors and throw our own
            raise CronofyError("Something is wrong", response.text, response.status_code)


class ListableAPIResource(APIResource):

    @classmethod
    def class_url(cls):
        cls_name = cls.class_name()
        if cls_name == "free_busy":
            return "/v1/free_busy"
        return "/v1/%ss" % (cls_name,)

    @classmethod
    def class_name_for_url(cls):
        cls_name = cls.class_name()
        if cls_name == "free_busy":
            return "free_busy"
        return "%ss" % cls_name.lower()

    @classmethod
    def all(cls, access_token, params):

        response = requests.get("%s%s" % (cronofy.api_base, cls.class_url(),),
                                params=params,
                                headers={'content-type': 'application/json', 'authorization': 'Bearer %s' % access_token})

        if response.status_code == requests.codes.ok:

            response_json = response.json()
            items = response_json[cls.class_name_for_url()]

            result = CronofyResultSet(convert_to_cronofy_object(items, cls.class_name().lower()))
            
            if "pages" in response_json:
                pages = response_json["pages"]

                if "next_page" in pages and pages["next_page"]:
                    result.next_page_url = pages["next_page"]
                    result.access_token = access_token
                    result.object_class = cls.class_name()
                    result.class_url = cls.class_url()
                    result.class_name_for_url = cls.class_name_for_url()
                    result.total_pages = pages['total']

            return result
        else:
            #TODO: wrap HTTP errors and throw our own
            raise CronofyError("Something is wrong", response.text, response.status_code)


class CronofyResultSet(list):
    next_page_url = None
    access_token = None
    object_class = None
    total_pages = None
    class_url = None
    class_name_for_url = None

    def next_page(self):
        if not self.next_page_url:
            return None

        response = requests.get(self.next_page_url,
                                headers={'content-type': 'application/json', 'authorization': 'Bearer %s' % self.access_token})

        if response.status_code == requests.codes.ok:
            response_json = response.json()
            items = response_json[self.class_name_for_url]
            
            result = CronofyResultSet(convert_to_cronofy_object(items, self.object_class.lower()))
            
            if "pages" in response_json:
                pages = response_json["pages"]

                if "next_page" in pages and pages["next_page"]:
                    result.next_page_url = pages["next_page"]
                    result.access_token = self.access_token
                    result.object_class = self.object_class
                    result.class_name_for_url = self.class_name_for_url
                    result.class_url = self.class_url

            return result
        else:
            #TODO: wrap HTTP errors and throw our own
            raise CronofyError("Something is wrong", response.text, response.status_code)

    def get_all_pages(self, max_pages=20):

        if self.total_pages is None or self.total_pages == 1:
            return self

        next_result = self
        results = []

        for i in range(min(self.total_pages - 1, max_pages)):

            next_result = next_result.next_page()
            if next_result is None:
                raise Exception
            results = results + next_result

        self.next_page_url = None
        return self + results


# API objects
class Calendar(ListableAPIResource, CreateAPIResourceMixin, CreateSubEventAPIResourceMixin,
               DeleteSubEventAPIResourceMixin):
    pass

class Profile(ListableAPIResource):
    pass

class FreeBusy(ListableAPIResource):
    pass

class Event(ListableAPIResource):
    @classmethod
    def all(cls, access_token, params=None):
        if params is None:
            params = {}

        if "tzid" not in params:
            params["tzid"] = "Etc/UTC"

        return super(Event, cls).all(access_token, params)

class Channel(ListableAPIResource, CreateAPIResourceMixin, DeleteAPIResourceMixin):
    @classmethod
    def all(cls, access_token, params=None):
        if params is None:
            params = {}

        return super(Channel, cls).all(access_token, params)

# Exceptions
class CronofyError(Exception):

    def __init__(self, message=None, http_body=None, http_status=None,
                 json_body=None):
        if http_body and hasattr(http_body, 'decode'):
            try:
                http_body = http_body.decode('utf-8')
            except:
                http_body = ('<Could not decode body as utf-8>')

        self.http_body = http_body

        self.http_status = http_status
        self.json_body = json_body
        super(CronofyError, self).__init__(message, http_body, http_status, json_body)

    def __str__(self):
        return repr(self)

    def __repr__(self):
        return "%s %s %s" % (super(CronofyError, self).__str__(), self.http_status, self.http_body)
