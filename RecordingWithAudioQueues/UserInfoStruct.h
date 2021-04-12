//
//  UserInfoStruct.h
//  RecordingWithAudioQueues
//
//  Created by Panayotis Matsinopoulos on 10/4/21.
//

#ifndef UserInfoStruct_h
#define UserInfoStruct_h

struct MyRecorder {
  AudioFileID recordFile;
  SInt64      recordPacket;
  Boolean     running;
};

typedef struct MyRecorder MyRecorder;

#endif /* UserInfoStruct_h */
