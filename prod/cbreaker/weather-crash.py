from flask import Flask
app = Flask(__name__)

@app.route("/")
def hello():
    raise Exception("I am out of service")

if __name__ == "__main__":
    app.run(host='0.0.0.0')
