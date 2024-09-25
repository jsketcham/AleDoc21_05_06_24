//
//  MidiCommands.h
//  MtcGenerator
//
//  Created by James Ketcham on 1/14/16.
//  Copyright © 2016 James Ketcham. All rights reserved.
//

#ifndef MidiCommands_h
#define MidiCommands_h

#define CC_AUTOSLATE 60
#define CC_PLAY_SAMPLE 22
#define CC_CAPTURE_FILL 21
#define CC_CAPTURE_SAMPLE 20    // 2.10.02
#define CC_VIDEO_REC_DELAY 0
#define CC_VIDEO_CALIBRATE_DELAY 2

// MIDI defines
#define NOTE_OFF 0x80
#define NOTE_ON 0x90
#define POLY_PRESSURE 0xa0
#define CONTROL_CHANGE 0xb0
#define PROG_CHANGE 0xc0
#define CHANNEL_PRESSURE 0xd0
#define PITCH_BEND 0xe0
#define SYSTEM_EXCLUSIVE 0xf0
#define MTC_QUARTER_FRAME 0xf1
#define SONG_POSITION_PTR 0xf2
#define SONG_SELECT 0xf3
#define META_EVENT 0xff
#define MIDI_EOX 0xf7
#define MIDI_CLK 0xf8
#define MIDI_START 0xfa
#define MIDI_CONTINUE 0xfb
#define MIDI_STOP 0xfc

// 256 byte buffer, index is a byte, leave it this size
#define MIDI_BUFFER_SIZE 0x100

typedef struct _MIDI_DISPLAY_FMT{
    
    unsigned char tc: 1;
    unsigned char ft_fr: 1;
    unsigned char bar_beat: 1;
    
}*pMIDI_DISPLAY_FMT,MIDI_DISPLAY_FMT;


// HUI zones
#define ZONE_MOTION 0xe
#define ZONE_DISPLAY 0x16
#define ZONE_FADER0 0
#define ZONE_FADER1 1
#define ZONE_FADER2 2
#define ZONE_FADER3 3
#define ZONE_FADER4 4
#define ZONE_FADER5 5
#define ZONE_FADER6 6
#define ZONE_FADER7 7

typedef struct _MIDI_MOTION{
    
    unsigned char talkback: 1;
    unsigned char rewind: 1;
    unsigned char fast_fwd: 1;
    unsigned char stop: 1;
    unsigned char play: 1;
    unsigned char record: 1;
    
}*pMIDI_MOTION,MIDI_MOTION;

#endif /* MidiCommands_h */
