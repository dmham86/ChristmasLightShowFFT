/*
 * Playback_BPF
 * 
 * Plays a soundfile, sound.mp3.
 * Applies a BPF, which is controlled interactively by the mouse 
 * (left-right is frequency, up-down is Q/bandwidth).
 * Plots the instantaneous spectrum, showing the effect of the filter.
 *
 * 2010-01-22 Dan Ellis dpwe@ee.columbia.edu
 */

import ddf.minim.analysis.*;
import ddf.minim.*;
import ddf.minim.effects.*;
import processing.serial.*;

int BUF_SIZE = 8;

Minim minim;
AudioPlayer sound;

BandPass bpf;
FFT fft;
Serial ardSerial;

boolean[][] buff = new boolean[16][BUF_SIZE];
float[] MaxValues = new float[16];
float[] MinValues = new float[16];
int[] x_loc = new int[16];
int[] y_loc = new int[16];
int myDataOut = 0;

int spectrumScale = 4; // pixels per FFT bin

void setup()
{
  size(512, 400);
  
  println(Serial.list());
  if(Serial.list().length > 1) {
    ardSerial = new Serial(this, Serial.list()[1], 9600);
    println("Connected to Arduino");
  }
  else {
    ardSerial = new Serial(this, Serial.list()[0], 9600);
  }
  
  minim = new Minim(this);
  minim.debugOff();
  
  sound = minim.loadFile("sound.mp3");
  // make it repeat
  sound.loop();

  // create an FFT object that has a time-domain buffer 
  // the same size as line-in's sample buffer
  fft = new FFT(sound.bufferSize(), sound.sampleRate());
  // Tapered window important for log-domain display
  fft.window(FFT.HAMMING);

  for(int i = 0; i < 16; i++) {
    MaxValues[i] = 0.0;
    MinValues[i] = 70.0;
    for(int j = 0; j < BUF_SIZE; j++)
       buff[i][j] = false; 
  }
  
  x_loc[2] = 1*(width/5); // Door
  y_loc[2] = 2*(height/4);
  x_loc[1] = 1*(width/5); // LR
  y_loc[1] = 3*(height/4);
  x_loc[0] = 2*(width/5); // RR
  y_loc[0] = 3*(height/4);
  x_loc[3] = 3*(width/5); // LP
  y_loc[3] = 3*(height/4);
  
  x_loc[4] = 1*(width/5); // B2
  y_loc[4] = 4*(height/4);
  x_loc[5] = 3*(width/5); // B3
  y_loc[5] = 4*(height/4);
  x_loc[6] =           0; // B1
  y_loc[6] = 4*(height/4);
  x_loc[7] = 4*(width/5); // B4
  y_loc[7] = 4*(height/4);
  
  x_loc[8] = 2*(width/5); // Tree
  y_loc[8] = 2*(height/4);
  x_loc[9] = 3*(width/5); // G1
  y_loc[9] = 2*(height/4);
  x_loc[10] = 4*(width/5); // G2
  y_loc[10] = 2*(height/4);
  
  x_loc[14] =            0; // R1
  y_loc[14] = 1*(height/4);
  x_loc[12] = 1*(width/5); // R2
  y_loc[12] = 1*(height/4);
  x_loc[11] = 2*(width/5); // R3
  y_loc[11] = 1*(height/4);
  x_loc[13] = 3*(width/5); // R4
  y_loc[13] = 1*(height/4);
  x_loc[15] = 4*(width/5); // R5
  y_loc[15] = 1*(height/4);
}

void mouseMoved()
{
  // map the mouse position to the range [100, 10000], an arbitrary range of passBand frequencies
  //centerFreq = map(mouseX, 0, width, 0, sound.sampleRate()/(2*spectrumScale));
}


void draw()
{
  float[] values = new float[16];
  int wid = fft.specSize()/128;
  background(0);
  fft.forward(sound.mix);
  fill(64,192,255);
  noStroke();
  for(int i = 0; i < (fft.specSize()/8) - 1; i++)
  {
    values[i/wid] += (fft.getBand(i)); //*Math.log10(10+i)
  }
  fill(255,192,64);
  for(int i = 0; i < 16; i++)
  {
    int flicker = 0;
    float val = values[i];

    for (int j = 0; j < BUF_SIZE-1; j++) {
      buff[i][j] = buff[i][j+1];
      if(buff[i][j] == true)
        flicker += 1;
    }
    buff[i][BUF_SIZE-1] = false;
    
    if( (val > MinValues[i]) ) {
      if( flicker > BUF_SIZE/8) { // Turn on only if there are a couple in the buffer
        // reduces false positives and flicker
        MinValues[i] *= 1.1 + .05*(16-i);
        segmentOn(i);
      }
      buff[i][BUF_SIZE-1] = true;
    }
    else {
      if( flicker > 1 ) {
       segmentOn(i);
      }
      if(MinValues[i] > 40.0)
        MinValues[i] *=.9;
    }
  }
  // Send to arduino
  ardSerial.write(myDataOut & 255);
  ardSerial.write( (myDataOut >> 8) & 255);
}

void segmentOn(int i) {
  rect(x_loc[i], y_loc[i], width/5, -height/4);
  myDataOut = myDataOut | 1<<i;
}

void keyReleased()
{
}

void stop()
{
  // always close Minim audio classes when you are done with them
  sound.close();
  ardSerial.stop();

  minim.stop();

  super.stop();
}


