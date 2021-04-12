//
//  main.m
//  RecordingWithAudioQueues
//
//  Created by Panayotis Matsinopoulos on 10/4/21.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <stdio.h>
#import "UtilityFunctions.h"
#import "UserInfoStruct.h"

// 1 buffer filling
// 1 buffer draining
// 1 buffer sitting in the middle as spare to account for any lag
#define kNumberOfRecordingBuffers 3
#define kBufferDurationInSeconds 0.5

static void MyAQInputCallback(void *inUserData,
                              AudioQueueRef inAQ,
                              AudioQueueBufferRef inBuffer,
                              const AudioTimeStamp *inStartTime,
                              UInt32 inNumberPacketDescriptions,
                              const AudioStreamPacketDescription *inPacketDescs) {
  MyRecorder *recorder = (MyRecorder *)inUserData;
  NSPrint(@"%@\n", recorder->running ? @"Recording [hit <Enter> to stop]..." : @"...stopped redording");
  
  if (inNumberPacketDescriptions > 0) {
    CheckError(AudioFileWritePackets(recorder->recordFile,
                                     FALSE,
                                     inBuffer->mAudioDataByteSize,
                                     inPacketDescs,
                                     recorder->recordPacket,
                                     &inNumberPacketDescriptions,
                                     inBuffer->mAudioData), "Writing packes to the Audio File");
    recorder->recordPacket += inNumberPacketDescriptions;
  }
  if (recorder->running) {
    CheckError(AudioQueueEnqueueBuffer(inAQ,
                                       inBuffer,
                                       0, NULL), "After having used the buffer enqueue back in the queue an empty one");
  }
}

int main(int argc, const char * argv[]) {
  if (argc < 2) {
    fprintf(stderr, "You need to give the output file name. We will automatically append the '.caf' extension because we generate CAF type files.");
    exit(1);
  }
  
  @autoreleasepool {
    // insert code here...
    NSPrint(@"Start recording command line application!");
    
    // Set up format
    AudioStreamBasicDescription recordFormat;
    memset(&recordFormat, 0, sizeof(recordFormat));
    
    recordFormat.mFormatID = kAudioFormatMPEG4AAC; // MPEG4 AAC, Advanced Audio Coding
    recordFormat.mChannelsPerFrame = 2;
    
    GetDefaultInputDeviceSampleRate(&recordFormat.mSampleRate);
    
    // Normally, first, we call the 'AudioFormatGetPropertyInfo' to get the
    // necessary data size to pass to the 'AudioFormatGetProperty'. However,
    // we already know that the 'kAudioFormatProperty_FormatInfo' property
    // will need size equal to sizeof(AudioStreamBasicDescription)' because
    // this is the structure it fills and returns back.
    
    UInt32 recordFormatSize = sizeof(recordFormat);
    CheckError(AudioFormatGetProperty(kAudioFormatProperty_FormatInfo,
                                      0,
                                      NULL,
                                      &recordFormatSize,
                                      &recordFormat), "Get the value of the audio format property '_FormaInfo'");
    
    // Set up queue
    MyRecorder recorder = {0};
    AudioQueueRef queue = {0};
    CheckError(AudioQueueNewInput(&recordFormat,
                                  MyAQInputCallback,
                                  &recorder,
                                  NULL,
                                  NULL,
                                  0,
                                  &queue), "Creating a new audio input queue");
    
    // The fact that we now have an AudioQueue, it means that we can update our
    // 'AudioStreamBasicDescription' at hand. The property that we can query info
    // for is 'kAudioQueueProperty_StreamDescription'.
    recordFormatSize = sizeof(recordFormat);
    CheckError(AudioQueueGetProperty(queue,
                                     kAudioQueueProperty_StreamDescription,
                                     &recordFormat,
                                     &recordFormatSize), "Getting the audio queue property kAudioQueueProperty_StreamDescription");
    
    // Set up file (e.g. "output.caf")
    NSString *audioFilePath = [[NSString stringWithUTF8String:argv[1]] stringByExpandingTildeInPath];
    NSURL *audioURL = [NSURL fileURLWithPath:audioFilePath];
    
    CheckError(AudioFileCreateWithURL((__bridge CFURLRef)audioURL,
                                      kAudioFileCAFType, // Core Audio Format (CAF)
                                      &recordFormat,
                                      kAudioFileFlags_EraseFile,
                                      &recorder.recordFile), "Creating audio file with URL");
    
    CopyEncoderCookieToFile(queue, recorder.recordFile);
    
    // Other setup as needed
    int bufferByteSize = ComputeRecordBufferSize(&recordFormat, queue, kBufferDurationInSeconds);
    
    int bufferIndex = 0;
    for(bufferIndex = 0; bufferIndex < kNumberOfRecordingBuffers; bufferIndex++) {
      AudioQueueBufferRef buffer;
      CheckError(AudioQueueAllocateBuffer(queue,
                                          bufferByteSize,
                                          &buffer), "Allocating a recording buffer");
      CheckError(AudioQueueEnqueueBuffer(queue, buffer, 0, NULL), "Enqueueing recording buffer");
    }
    
    // Start queue
    recorder.running = TRUE;
    CheckError(AudioQueueStart(queue, NULL), "Starting audio queue");

    NSPrint(@"...Recording...press <return> to stop\n");
    getchar();
    
    recorder.running = FALSE;

    // Stop queue
    CheckError(AudioQueueStop(queue, TRUE), "Stopping audio queue");
    
    // clean up
    
    // a codec may update its magic cookie at the end of an encoding session
    // so reapply it to the file now
    CopyEncoderCookieToFile(queue, recorder.recordFile);
    
    CheckError(AudioQueueDispose(queue, TRUE), "Disposing audio queue");
    
    CheckError(AudioFileClose(recorder.recordFile), "Closing audio file");
    
    NSPrint(@"...ending");
    
  }
  return 0;
}
