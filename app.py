from logging import exception
from tkinter import E
import psycopg2,json
import re
import jwt
from flask import Flask, jsonify, redirect, url_for, request
from sqlalchemy import FetchedValue, false, true
app = Flask(__name__)

# establishing the connection
conn = psycopg2.connect(
    database="db",
    user='johndoe',
    password='p4ssw0rd',
    host='localhost',
    port='5432'
)

# Creating a cursor object using the cursor()
# method
cursor = conn.cursor()

'''
@app.route('/')
def index():
    return jsonify({'name': 'alice',
                    'email': 'alice@outlook.com'})
'''

def is_valid_token(vendor, access_token):
    cursor.execute(
        "SELECT * FROM vendors.public_key WHERE vendor_id = %s;", (vendor.lower(),))
    records = cursor.fetchall()
    publickkey = ''
    if len(records) > 0:

        #print("vendor: ", records[0][0])

        public_key = records[0][1]

        #print("publick key: ", public_key)

    access_token = access_token.replace('Bearer ', '')
    # print(access_token)
    # print(public_key)
    # validate JWT Token
    #decoded = jwt.decode(access_token, public_key, algorithms=["ES384"])
    #decoded = jwt.decode(access_token, public_key, algorithms=["ES384"], options = {'verify_exp':False})
    nonce = ''
    #public_key = 'testing wrong publick key'
    try:

        decoded = jwt.decode(access_token, public_key, algorithms=[
                            "ES384"],  options={"verify_exp": False})
        nonce = decoded['nonce']
    except Exception as e:
        print("Oops!", e.__class__, "occurred.")
        return ''
        
    return nonce


def fetch_user_details(email, nonce):
    patient_info = None
    try:
        cursor.execute(
            "SELECT * FROM users.profile WHERE email = %s;", (email,))
        # print(cursor.fetchall())
        # build JSON
        user_records = cursor.fetchall()
        if user_records is not None and len(user_records) > 0:
            user_id =  user_records[0][0]
            first_name = user_records[0][3]
            last_name = user_records[0][4]
            dob = user_records[0][11]
            phone = user_records[0][12]

            #address
            cursor.execute(
                "SELECT * FROM users.address WHERE user_id  = %s;", (user_id,))
            address_records = cursor.fetchall()

            address_id = address_records[0][0]
            line1 = address_records[0][3]
            line2 = address_records[0][4]
            city = address_records[0][5]
            state = address_records[0][6]
            county = address_records[0][7]
            zip = address_records[0][8]
            country = address_records[0][9]

            patient_info = {
                "nonce": nonce,
                "user_id": user_id,
                "first_name": first_name,
                "last_name": last_name,
                "email": email,
                "dob": dob,
                "phone": phone,
                "addresses": [
                    {
                        "id": address_id,
                        "line1": line1,
                        "line2": line2,
                        "city": city,
                        "state": state,
                        "county": county,
                        "zip": zip,
                        "country": country
                    }
                ]
            }
    except Exception as e:
        print("Oops!", e.__class__, "occurred.")
        return None

    return patient_info
    
@app.route('/api/v1/webhook', methods=['POST'])
def get_user():

    reqdata = request.json
    email = reqdata["email"]

    headers = request.headers
    vendor = ''
    access_token = ''
    for header in headers:
        headerkey = header[0]

        p = re.compile('X-(.*)-Token')
        results = p.findall(headerkey)
        if len(results) > 0:
            vendor = p.findall(headerkey)[0]
            access_token = header[1]
            #print(vendor)
            break
    nonce = ''
    nonce = is_valid_token(vendor, access_token)
    patient_details = {}
    if nonce != '':
        patient_details = fetch_user_details(email, nonce)
        if not patient_details:
            return "", 204
        else:
            return patient_details, 200, {'ContentType':'application/json'}
    else:
        return "", 401

app.run()
