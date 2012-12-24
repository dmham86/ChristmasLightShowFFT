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
import java.io.*;

boolean connected = true; // Whether or not the serial is connected
int BUF_SIZE = 12;
// Replace this line with your folder path
String filepath = "C:/Users/David/Music/christmasLightMusic";

Minim minim;
AudioPlayer sound;
AudioInput in;
AudioOutput out;
AudioSocket socket;
String[] filenames;
int songNum = 0;

BandPass bpf;
FFT fft;
Serial ardSerial;

boolean[][] buff = new boolean[16][BUF_SIZE];
float[] MaxValues = new float[16];
float[] MinValues = new float[16];
int[] x_loc = new int[16];
int[] y_loc = new int[16];
int[] segmentToPlug;
int myDataOut = 0;

  // Give them names to make easier troubleshooting
  // Numbers here indicate the frequency band from the FFT
  // Lower = left on the graph
  int R1 = 14, R2 = 12, R3 = 11, R4 = 13, R5 = 15;
  int B1 = 6, B2 = 4, B3 = 5, B4 = 7;
  int LP = 3, LR = 0, RR = 2, TR = 8;
  int FD = 1, G1 = 9, G2 = 10;
  
  // This is the order they are plugged in
  int [] plugToSegment = {R1, R2, R3, FD, RR, LR, TR, B2,
                          G1, G2, R4, R5, B3, B4, B1, LP};

int spectrumScale = 4; // pixels per FFT bin

void setup()
{
  size(512, 400);
  
  frameRate(30); // Slow it down some
  
  if(connected) {
    println(Serial.list());
    if(Serial.list().length > 1) {
      ardSerial = new Serial(this, Serial.list()[1], 9600);
      println("Connected to Arduino");
    }
    else {
      ardSerial = new Serial(this, Serial.list()[0], 9600);
    }
  }
  
  // Need to wait until the arduino is ready 
  for(int j = 0; j < 10; j++){
  for(float i = 0; i < 2000.0; i += .0001){
    i-=.000001;
  }
  }
  
  minim = new Minim(this);
  minim.debugOff();
  
  // we'll have a look in the data folder
java.io.File folder = new java.io.File(filepath);
 
// let's set a filter (which returns true if file's extension is .jpg)
java.io.FilenameFilter mp3Filter = new java.io.FilenameFilter() {
  public boolean accept(File dir, String name) {
    return name.toLowerCase().endsWith(".mp3");
  }
};
 
// list the files in the data folder, passing the filter as parameter
  filenames = folder.list(mp3Filter);
  
  for (int i = 0; i < filenames.length; i++) {
  println(filenames[i]);
}
  
  sound = minim.loadFile(filepath+"/"+filenames[(int)random(filenames.length)]);
  sound.play();
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
  

  segmentToPlug = new int[16];
  for(int i = 0; i < 16; i++) {
    segmentToPlug[i] = 1<<plugToSegment[i];
    //println(1<<plugToSegment[i]);
  }
  
    // This is just for display purposes while debugging
  x_loc[FD] = 1*(width/5); // Door
  y_loc[FD] = 2*(height/4);
  x_loc[LR] = 1*(width/5); // LR
  y_loc[LR] = 3*(height/4);
  x_loc[RR] = 2*(width/5); // RR
  y_loc[RR] = 3*(height/4);
  x_loc[LP] = 3*(width/5); // LP
  y_loc[LP] = 3*(height/4);
  
  x_loc[B2] = 1*(width/5); // B2
  y_loc[B2] = 4*(height/4);
  x_loc[B3] = 3*(width/5); // B3
  y_loc[B3] = 4*(height/4);
  x_loc[B1] =           0; // B1
  y_loc[B1] = 4*(height/4);
  x_loc[B4] = 4*(width/5); // B4
  y_loc[B4] = 4*(height/4);
  
  x_loc[TR] = 2*(width/5); // Tree
  y_loc[TR] = 2*(height/4);
  x_loc[G1] = 3*(width/5); // G1
  y_loc[G1] = 2*(height/4);
  x_loc[G2] = 4*(width/5); // G2
  y_loc[G2] = 2*(height/4);
  
  x_loc[R1] =            0; // R1
  y_loc[R1] = 1*(height/4);
  x_loc[R2] = 1*(width/5); // R2
  y_loc[R2] = 1*(height/4);
  x_loc[R3] = 2*(width/5); // R3
  y_loc[R3] = 1*(height/4);
  x_loc[R4] = 3*(width/5); // R4
  y_loc[R4] = 1*(height/4);
  x_loc[R5] = 4*(width/5); // R5
  y_loc[R5] = 1*(height/4);
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
  myDataOut = 0;
  
  if(!sound.isPlaying()) {
    sound = minim.loadFile(filepath+"/"+filenames[(int)random(filenames.length)]);
    sound.play();
    // the same size as line-in's sample buffer
  fft = new FFT(sound.bufferSize(), sound.sampleRate());
  // Tapered window important for log-domain display
  fft.window(FFT.HAMMING);
  }
  
  background(0);
  fft.forward(sound.mix);
  fill(255,192,64);
  noStroke();
  for(int i = 0; i < (fft.specSize()/8) - 1; i++)
  {
    values[i/wid] += (fft.getBand(i)); //*Math.log10(10+i)
  }
  
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
        MinValues[i] *= (.9 + .005*(16-i));
    }
  }
  // Send to arduino
  if(connected) {
    ardSerial.write( myDataOut );
    ardSerial.write( myDataOut >> 4);
    ardSerial.write( (myDataOut >> 8) );
    ardSerial.write( myDataOut >> 12);
  }
}

void segmentOn(int i) {
  rect(x_loc[i], y_loc[i], width/5, -height/4);
  myDataOut = myDataOut | segmentToPlug[i];
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


/// Audio Socket Code

class AudioSocket implements AudioListener, AudioSignal
{

  private float[] left;
  private float[] right;
  private int buffer_max;
  private int inpos, outpos;
  private int count;
  
  // AudioSocket makes and AudioSignal out of an AudioListener.
  // That is, it will accept the samples supplied to it by other 
  // AudioSignals (like an AudioListener), but then it will 
  // pass these on to any listeners to which it is connected.
  // To deal with scheduling asynchronies, it maintains an 
  // internal FIFO buffer to temporarily stage samples it 
  // has been given until it has somewhere to send them.
  
  // Assumes that samples will always enter and exit in blocks 
  // of buffer_size, so we don't have to worry about splitting 
  // blocks across the ring-buffer boundary

  AudioSocket(int buffer_size)
  {
     int n_buffers = 4;
     buffer_max = n_buffers * buffer_size;
     left = new float[buffer_max];
     right = new float[buffer_max];
     inpos = 0;
     outpos = 0;
     count = 0;
  }

  // The AudioListener:samples method accepts new input samples
  synchronized void samples(float[] samp)
  {
    // handle mono by writing samples to both left and right
    samples(samp, samp);
  }

  synchronized void samples(float[] sampL, float[] sampR)
  {
    System.arraycopy(sampL, 0, left, inpos, sampL.length);
    System.arraycopy(sampR, 0, right, inpos, sampR.length);
    inpos += sampL.length;
    if (inpos == buffer_max) {
      inpos = 0;
    }
    count += sampL.length;
    // println("samples: count="+count);
  }

  // The AudioSignal:generate method supplies new output 
  // samples when requested
  void generate(float[] samp)
  {
     // println("generate: count="+count);
     if (count > 0) {
       System.arraycopy(left, outpos, samp, 0, samp.length);
       outpos += samp.length;
       if (outpos == buffer_max) {
         outpos = 0;
       }
       count -= samp.length;
     }
  }

  void generate(float[] sampL, float[] sampR)
  {
     // handle stereo by copying one channel, then passing the other channel 
     // to the mono handler which will update the pointers
     if (count > 0) {
       System.arraycopy(right, outpos, sampR, 0, sampR.length);
       generate(sampL);
     }
  }
}

