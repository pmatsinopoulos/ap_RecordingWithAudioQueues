//
//  utility_functions.m
//  RecordingWithAudioQueues
//
//  Created by Panayotis Matsinopoulos on 10/4/21.
//

#import <Foundation/Foundation.h>
#import <ctype.h>
#import <stdio.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioToolbox/AudioFile.h>
#import <AudioToolbox/AudioQueue.h>

void NSPrint(NSString *format, ...) {
  va_list args;

  va_start(args, format);
  NSString *string  = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);

  fprintf(stdout, "%s", [string UTF8String]);
    
#if !__has_feature(objc_arc)
  [string release];
#endif
}

void CheckError(OSStatus error, const char *operation) {
  if (error == noErr) {
    return;
  }
  
  char errorString[20];
  *(UInt32 *)(errorString + 1) = CFSwapInt32HostToBig(error); // we have 4 bytes and we put them in Big-endian ordering. 1st byte the biggest
  if (isprint(errorString[1]) && isprint(errorString[2]) &&
      isprint(errorString[3]) && isprint(errorString[4])) {
    errorString[0] = errorString[5] = '\'';
    errorString[6] = '\0';
  } else {
    sprintf(errorString, "%d", (int) error);
  }
  NSLog(@"Error: %s (%s)\n", operation, errorString);
  exit(1);
}

void GetDefaultInputDeviceSampleRate(Float64 *oSampleRate) {
  AudioObjectPropertyAddress propertyAddress;
  
  propertyAddress.mSelector = kAudioHardwarePropertyDefaultInputDevice;
  propertyAddress.mScope = kAudioObjectPropertyScopeGlobal;
  propertyAddress.mElement = 0; // master element
  
  AudioDeviceID deviceID = 0;
  UInt32 propertySize = sizeof(AudioDeviceID);
  
  CheckError(AudioObjectGetPropertyData(kAudioObjectSystemObject,
                                        &propertyAddress,
                                        0,
                                        NULL,
                                        &propertySize,
                                        &deviceID), "Getting default input device ID from Audio System Object");
  
  propertyAddress.mSelector = kAudioDevicePropertyNominalSampleRate;
  propertyAddress.mScope = kAudioObjectPropertyScopeGlobal;
  propertyAddress.mElement = 0;
  propertySize = sizeof(Float64);
  
  CheckError(AudioObjectGetPropertyData(deviceID,
                                        &propertyAddress,
                                        0,
                                        NULL,
                                        &propertySize,
                                        oSampleRate), "Getting nominal sample rate for the default device");
}

void CopyEncoderCookieToFile(AudioQueueRef queue, AudioFileID fileHandle) {
  UInt32 propertyValueSize = 0;
  CheckError(AudioQueueGetPropertySize(queue,
                                       kAudioQueueProperty_MagicCookie,
                                       &propertyValueSize), "Getting the size of the value of the Audio Queue property kAudioConverterCompressionMagicCookie");
  if (propertyValueSize > 0) {
    UInt8 *magicCookie = (UInt8 *)malloc(propertyValueSize);
    CheckError(AudioQueueGetProperty(queue,
                                     kAudioQueueProperty_MagicCookie,
                                     (void *)magicCookie,
                                     &propertyValueSize), "Getting the value of the Audio Queue property kAudioQueueProperty_MagicCookie");
    
    CheckError(AudioFileSetProperty(fileHandle,
                                    kAudioFilePropertyMagicCookieData,
                                    propertyValueSize,
                                    magicCookie
                                    ), "Setting the AudioFile property kAudioFilePropertyMagicCookieData");
    free(magicCookie);
  }
}

int ComputeRecordBufferSize(const AudioStreamBasicDescription *format, AudioQueueRef queue, float seconds) {
  assert(seconds > 0);
  assert(format->mSampleRate > 0);
  
  int totalNumberOfSamples = seconds * format->mSampleRate;
  int totalNumberOfFrames = (int)ceil(totalNumberOfSamples);
  
  if (format->mBytesPerFrame > 0) {
    return totalNumberOfFrames * format->mBytesPerFrame;
  }
  UInt32 maxPacketSize = 0;
  
  if (format->mBytesPerPacket > 0) {
    maxPacketSize = format->mBytesPerPacket;
  } else {
    UInt32 propertySize = sizeof(maxPacketSize);
    CheckError(AudioQueueGetProperty(queue,
                                     kAudioQueueProperty_MaximumOutputPacketSize,
                                     &maxPacketSize,
                                     &propertySize), "Getting Audio Queue property kAudioQueueProperty_MaximumOutputPacketSize");
  }
  
  int totalNumberOfPackets = 0;
  int numberOfFramesPerPacket = 1;
  
  if (format->mFramesPerPacket > 0) {
    numberOfFramesPerPacket = format->mFramesPerPacket;
  }
  
  totalNumberOfPackets = totalNumberOfFrames / numberOfFramesPerPacket;
    
  // We have number of packets and packet size. Hence we can now get the number of bytes needed.
  return totalNumberOfPackets * maxPacketSize;
}
