#include <Wire.h>
#include <LiquidCrystal_I2C.h>
#include "DHT.h"

#define DHTPIN 9 //Pin auquel est connecté le capteur DHT
#define DHTTYPE DHT11 //Si vous utiliser le DHT 11
#define BUZZER 31

DHT dht(DHTPIN, DHTTYPE); //On initialise le capteur DHT
LiquidCrystal_I2C lcd(0x27, 2, 1, 0, 4, 5, 6, 7, 3, POSITIVE);

// déclaration des registres
byte regs[7]; 
int regIndex = 0; // Registre à lire ou à écrire.
float h, t;
// copie de la dernière instruction d execution écrite dans
// le registre reg0 pour le traitement asynchrone de
// requestEvent (demande de bytes) 
byte lastExecReq = 0x00; 

void setup()
{
  // Initialisation des registres
  regs[0] = 0x00; // reg0 = registre d'exécution
  regs[1] = 0x00; 
  regs[2] = 0x00;
  regs[3] = 0x00;
  regs[4] = 0x00;
  regs[5] = 0x00;
  regs[6] = 0x00;
  
  // Joindre le Bus I2C avec adresse #4
  Wire.begin(4);

  // enregistrer l'événement 
  //    Lorsque des données sont écrites par le maitre et reçue par l'esclave
  Wire.onReceive(receiveEvent); 
  // enregistrer l'événement 
  //    Lorsque le Maitre demande de lecture de bytes
  Wire.onRequest(requestEvent); 

  // Démarrer une communication série
  Serial.begin(19200);           
  Serial.println( F("Bus I2C pret") );

  // Definir la broche 31 en sortie
  pinMode( BUZZER, OUTPUT );
  //digitalWrite( BUZZER, LOW );
  //delay(500);
  digitalWrite( BUZZER, HIGH);

  dht.begin();
  lcd.begin(16,2);

  lcd.backlight();
}

void loop()
{
  h = dht.readHumidity(); //Pourcentage d'humidité mesuré
  t = dht.readTemperature(); //Température mesurée en Celsius

  // Si NOP alors rien à faire
  if( regs[0] == 0x00 ) {
    delay(100);
    return;
  }

  switch( regs[0] ){
  case 0x01 : // demande de version (rien à faire)
    break;

  case 0x02 : // demande de valeur Float (rien à faire, l'operation et retour de donnée est exécuté à la demande de réponse)
    break;

  case 0x03:
    if (regs[1]==1)
    {
      lcd.clear();
      lcd.setCursor(0, 0); //Positionnement du curseur
      lcd.print("Degres : ");
      lcd.setCursor(9, 0);
      lcd.print(t); //Affichage de la température
      lcd.setCursor(13, 0);
      lcd.print((char)223); //Affiche le caractère ° (degrés)
      lcd.setCursor(14, 0);
      lcd.print("C"); //En degrés Celsuis
      lcd.setCursor(0, 1);
      lcd.print("Humidite : ");
      lcd.setCursor(11, 1);
      lcd.print(h); //Affichage de l'humidité
      lcd.setCursor(15, 1);
      lcd.print("%");
    }
    else
    {
      //Afficher addresse ip du rasp
      lcd.clear();
      lcd.setCursor(0,0);
      lcd.print("IP:");
      lcd.print(regs[3]);//192
      lcd.print(".");
      lcd.print(regs[4]);//168
      lcd.print(".");
      lcd.print(regs[5]);//0
      lcd.print(".");
      lcd.print(regs[6]);//14
      lcd.print(".");
    }
    break;

  case 0x04:
    //Buzzer avec seconde dans registre 1
    digitalWrite(31, LOW);
    delay(regs[1]);
    digitalWrite(31, HIGH);
    break;
  } 
  // reset to NOP
  regs[0] = 0x00;  
}

// Fonction qui est exécutée lorsque des données sont envoyées par le Maître.
// Cette fonction est enregistrée comme une événement ("event" en anglais), voir la fonction setup()
void receiveEvent(int howMany)
{
  int byteCounter = 0;

  // Lire tous les octets sauf le dernier
  while( byteCounter < howMany ) 
  {
    // lecture de l'octet
    byte b = Wire.read();     
    byteCounter += 1;

    //Serial.println( b, DEC );

    if( byteCounter == 1 ){   // Byte #1 = Numéro de registre
      regIndex = b;
    } 
    else {                    // Byte #2 = Valeur a stocker dans le registre
      switch(regIndex) {

      //Actions
      case 0:
        regs[0] = b;
        // maintenir une copie du dernier reg0 pour 
        // traitement d'une réponse via requestEvent (demande de byte)
        lastExecReq = b; 
        break;

      //Valeurs
      case 1: 
        regs[1] = b;
        break;
      case 2:
        regs[2] = b;
        break;

      //Addresse IP
      case 3:
        regs[3] = b;
        break;
      case 4:
        regs[4] = b;
        break;
      case 5:
        regs[5] = b;
        break;
      case 6:
        regs[6] = b;
        break;
      } 
    }


  }
}


// Fonction outil décomposant un double en array de Bytes 
// et envoyant les données sur le bus I2C
//
// Basé sur le code obtenu ici:
//      http://stackoverflow.com/questions/12664826/sending-float-type-data-from-arduino-to-python
void Wire_SendDouble( double* d){

  // Permet de partager deux types distinct sur un meme espace
  // memoire
  union Sharedblock
  {
    byte part[4]; // utiliser char parts[4] pour port série
    double data;

  } 
  mon_block;

  mon_block.data = *d;

  Wire.write( mon_block.part, 4 );
}

double valeurDouble;

// Fonction est activé lorsque le Maitre fait une demande de lecture.
// 
void requestEvent()
{
  // Deboggage - Activer les lignes suivantes peut perturber fortement 
  //    l'échange I2C... a utiliser avec circonspection.
  //
  //   Serial.print( "Lecture registre: " );
  //   Serial.println( regIndex );

  // Quel registre est-il lu???
  switch( regIndex ){ 

  case 0x00: // lecture registre 0 
    // la réponse depend de la dernière opération d'exécution demandée 
    //    par l'intermédiaire du registre d'exécution (reg 0x00).
    switch( lastExecReq ) {
    case 0x01: // demande de version
      // current version = v3
      Wire.write( 0x11 ); 
      break;

    case 0x02: //Temperature 
      Serial.print("Temperature :");
      Serial.print(t);
      Serial.print("°C\n");
      // Décompose la valeur en Bytes et l'envoi sur I2C
      Wire_SendDouble( (double*)&t);
      break;

    case 0x44: //Humidité
      Serial.print("Humidité :");
      Serial.print(h);
      Serial.print("%\n");
      // Décompose la valeur en Bytes et l'envoi sur I2C
      Wire_SendDouble( (double*)&h);
      break;

    default:
      Wire.write( 0xFF ); // ecrire 255 = il y a un problème! 
    }
    break;

  default: // lecture autre registre 
    Wire.write( 0xFF ); // ecrire 255 = il y a un problème
  }  

}


