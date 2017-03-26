from flask import Flask
import time

app = Flask(__name__)

@app.route("/")
def hello():
    time.sleep(30)
    raise Exception("System overloaded")

if __name__ == "__main__":
    app.run(host='0.0.0.0')
