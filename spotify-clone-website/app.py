from flask import Flask
from flask import render_template
from flask import send_from_directory
from flask import jsonify
import os

app = Flask(__name__)

VERSION = os.getenv("WEBSITE_VERSION", "v1.0.0")

@app.route("/")
def hello():
    return render_template('index.html', message='Hello, World!')

@app.route("/version")
def version():
    return jsonify({"version": VERSION})

if __name__ == "__main__":

    # If I enable `debug=True` I get
    # `KeyError: 'getpwuid(): uid not found: 1000060000'` errors
    # from OpenShift.
    app.run(host='0.0.0.0', port=8080)