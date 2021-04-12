//
//  UtilityFunctions.h
//  RecordingWithAudioQueues
//
//  Created by Panayotis Matsinopoulos on 10/4/21.
//

#ifndef UtilityFunctions_h
#define UtilityFunctions_h

#import <MacTypes.h>

void NSPrint(NSString *format, ...);
void CheckError(OSStatus error, const char *operation);
void GetDefaultInputDeviceSampleRate(Float64 *oSampleRate);
void CopyEncoderCookieToFile(AudioQueueRef queue, AudioFileID fileHandle);
int ComputeRecordBufferSize(const AudioStreamBasicDescription *format, AudioQueueRef queue, float seconds);

#endif /* UtilityFunctions_h */
