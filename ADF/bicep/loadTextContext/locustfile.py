from locust import HttpUser, TaskSet, task, between
from locust.contrib.fasthttp import FastHttpUser
import os
import uuid


class WebsiteUser(FastHttpUser):
    """
    User class that does requests to the locust web server running on localhost,
    using the fast HTTP client
    """
    # a = ones((4096), dtype=uint8)
    #N = 100000
    #bits = random.getrandbits(N)
    wait_time = between(.2, 1.5)
    # some things you can configure on FastHttpUser
    # connection_timeout = 60.0
    # insecure = True
    # max_redirects = 5
    # max_retries = 1
    # network_timeout = 60.0

    # @task
    # def index(self):
    #     self.client.get("/api/test")


    

    # @task
    # def stats(self):
    #     with open('/home/locust/locust/test.txt', 'rb') as f:
    #         self.client.post("/api/post", data={'pxeconfig': f.read()})

    @task
    def stats(self):
        byte = os.urandom(1400)
        self.client.post("/GetWeatherForecast", headers={'X-request-key': str(uuid.uuid4())}, data={'bytearray': byte})