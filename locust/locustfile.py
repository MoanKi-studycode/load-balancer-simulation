from locust import HttpUser, task, constant_throughput

class WebsiteUser(HttpUser):
    wait_time = constant_throughput(0.6)

    @task
    def hit_homepage(self):
        self.client.cookies.clear()
        self.client.get("/")
