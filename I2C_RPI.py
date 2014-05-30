#!/usr/bin/env python
# -*- coding: latin-1 -*-

import time
import struct
import socket
import urllib2
import MySQLdb
from Adafruit_I2C import Adafruit_I2C

Vert = 31
Rouge = 30
#Addresse de l'arduino
i2c = Adafruit_I2C( 0x04 )

def Temperature(): 
	i2c.write8( 0x00, 0x02 )
	time.sleep(0.100)
	i2c.debug = False
	lstData =  i2c.readList( 0x00, 4 )
	sData = ''
	for aByte in lstData:
        	sData = sData + chr(aByte)

	f_data, = struct.unpack('<f',sData)
	return f_data # Affiche la valeur en Float
	time.sleep(0.100)

def Humidite():
        i2c.write8( 0x00, 0x03 )
        time.sleep(0.100)
        i2c.debug = False
        lstData =  i2c.readList( 0x00, 4 )
        sData = ''
        for aByte in lstData:
                sData = sData + chr(aByte)

        f_data, = struct.unpack('<f',sData)
        return f_data

db = MySQLdb.connect("localhost", "root", "raspberry", "temperature")
curs=db.cursor()

try :
	curs.execute ("""INSERT INTO ValeurSonde 
            VALUES(CURRENT_DATE(), NOW(),%s,%s)""",(Temperature(),Humidite()))

    	db.commit()
    	print "Data committed"

except :
	print "Error: the database is being rolled back"
    	db.rollback()
