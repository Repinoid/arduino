import os
import json
import boto3
import json
import base64
import time
from botocore.exceptions import ClientError
from boto3.dynamodb.conditions import Key
from decimal import Decimal
from datetime import datetime
from decimal import Decimal

TableName = 'temp_and_humid'
timezona = 4 # real time UTC + timezona hours

document_api_endpoint = os.getenv("document_api_endpoint")


def create_iot_ydb_table(event, context):
    #    document_api_endpoint = os.getenv("document_api_endpoint")
    ydb_client = boto3.resource('dynamodb', endpoint_url=document_api_endpoint)
    table = ydb_client.create_table(
        TableName=TableName,
        KeySchema=[
            {
                'AttributeName': 'device_id',       # ID устройства
                'KeyType': 'HASH'  # Ключ партицирования
            },
            {
                'AttributeName': 'date',            # Дата сообщения
                'KeyType': 'RANGE'  # Ключ сортировки
            },

        ],
        AttributeDefinitions=[
            {
                'AttributeName': 'device_id',
                'AttributeType': 'S'                # String
            },
            {
                'AttributeName': 'date',
                'AttributeType': 'S'                # Строка
            },
            {
                'AttributeName': 'temperature',
                'AttributeType': 'S'                # Строка
            },
            {
                'AttributeName': 'humidity',
                'AttributeType': 'S'                # Строка
            },
        ]
    )
    return table


def trigga(event, context):
    document_api_endpoint = os.getenv("document_api_endpoint")                  # YDB endpoint sent by enviroment variables
    client = boto3.resource('dynamodb', endpoint_url=document_api_endpoint)
    message = json.dumps(event["messages"][0])
    json_msg = json.loads(message)
    device_id = json_msg["details"]["device_id"]
    decoded_payload = base64.b64decode(json_msg["details"]["payload"]).decode("KOI8-R")
    record_list = (decoded_payload.strip("/")).split("/")
    recs = []
    for  rec_num in range(len(record_list)):
        splitted = record_list[rec_num].split(";")
        ti = datetime.fromtimestamp(int(splitted[1]) + 60*60*timezona)
        date = ti.strftime('%Y-%m-%d %H:%M:%S')
        temper = (splitted[2])
        humid = (splitted[3])
        record = {
            "device_id":    device_id,
            "date":         date,
            "temperature":  temper,
            "humidity":     humid,
        }
        recs.append(record)
#    ret = write_one_measurement(recs[0], document_api_endpoint)
    ret =  write_bunches(client, recs)
    print(f"-------------------------- {decoded_payload} ------------------------============")
    last_rec = f"measurement_time = {splitted[1]}; \r\nmeasurement_temperature = {temper}; \r\nmeasurement_humidity = {humid};"
    iot2bucket(last_rec)
    return (recs)


def write_bunches(client, massa):
    #    client = boto3.resource('dynamodb', endpoint_url = document_api_endpoint)
    start_time = time.time()
    bunch_size = 25                                     # 25 - max bunch size
    cel = len(massa) // bunch_size           # количество полных банчей
    # записей в последнем, неполном, банче
    ostatok = len(massa) % bunch_size
    # количество полных банчей плюс последний огрызок
    for bunch_num in range(cel+1):
        # размер цикла =  bunch_size, если последний - то ostatok, который может быть и 0
        cycles = bunch_size if (bunch_num != cel) else ostatok
        # инициализация списка текучего банча
        bunch = []
        for i in range(cycles):
            # numb - индекс записи в общем списке
            numb = bunch_size * bunch_num + i
            # one Temperature Humidity record
            th_record = massa[numb]
            item_dict = {
                "device_id":        th_record["device_id"],
                "date":             th_record["date"],
                "temperature":      th_record["temperature"],
                "humidity":         th_record["humidity"],
            }
            record_putts = {"PutRequest": {"Item": item_dict}}
            bunch.append(record_putts)
        response = 77
        try:
            response = client.batch_write_item(RequestItems={TableName: bunch})
 #           print(f">>>>>>>>>>>>> {bunch}  <<<<<<<<<<<<<<response<< {response} <<<<<<<<<<<<<<<")
        except Exception as erro:
            exc = f"\tException '{erro}' occured\n\ttype '{type(erro)}'"
            print(exc)
            return (exc)
    return (response)


def iot2bucket(payload):
    session = boto3.session.Session()
    client = session.client(
        service_name='s3',
        endpoint_url='https://storage.yandexcloud.net'
    )
    try:
        response = client.put_object(
            Bucket='pogoda',
            Body=payload,
            Key=f"temp_humid_last_datas.js",
        )
    except Exception as erro:
        exc = f"\tException '{erro}' occured\n\ttype '{type(erro)}'"
        print(exc)
        return (exc)
    return response


def write_one_measurement(item, document_api_endpoint):
    ydb_client = boto3.resource('dynamodb', endpoint_url=document_api_endpoint)
    table = ydb_client.Table(TableName)
    try:
        response = table.put_item(Item=item)
        print(f">>>>>>>>>>>>>  <<<<<<<<<<<<<<response<< {response} <<<<<<<<<<<<<<<")
    except Exception as erro:
        exc = f"\tException '{erro}' occured\n\ttype '{type(erro)}'"
        print(exc)
        return (exc)
    return response


""" 

            {
                'AttributeName': 'temperature',            # Дата сообщения
                'KeyType': 'RANGE'  # Ключ сортировки
            },
            {
                'AttributeName': 'humidity',            # Дата сообщения
                'KeyType': 'RANGE'  # Ключ сортировки
            },





def read_table(event, context):
    ydb_docapi_client = boto3.resource(
        'dynamodb', endpoint_url=document_api_endpoint)
    table = ydb_docapi_client.Table('docapitest')
    response = table.get_item(
        Key=event
    )
    return response['Item']


def query(event, context):
    ydb_docapi_client = boto3.resource(
        'dynamodb', endpoint_url=document_api_endpoint)
    table = ydb_docapi_client.Table('docapitest')
    response = table.query(
        KeyConditionExpression=Key('series_id').eq(event)
    )
    return response['Items']
 """
