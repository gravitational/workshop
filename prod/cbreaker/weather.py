from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    return '''Pleasanton, CA
Saturday 8:00 PM
Partly Cloudy
12 C
Precipitation: 9%
Humidity: 74%
Wind: 14 km/h
'''

if __name__ == "__main__":
    app.run(host='0.0.0.0')
