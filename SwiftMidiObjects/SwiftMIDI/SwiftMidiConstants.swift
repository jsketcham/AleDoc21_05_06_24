//
//  MidiConstants.swift
//  UdpServer
//
//  Created by Jim on 2/18/22.
//

import Foundation

let MIDI_BUFFER_SIZE = 256

let NOTE_OFF : UInt8 = 0x80
let NOTE_ON : UInt8 = 0x90
let POLY_PRESSURE : UInt8 = 0xa0
let CONTROL_CHANGE : UInt8 = 0xb0
let PROG_CHANGE : UInt8 = 0xc0
let CHANNEL_PRESSURE : UInt8 = 0xd0
let PITCH_BEND : UInt8 = 0xe0
let SYSTEM_EXCLUSIVE : UInt8 = 0xf0
let MTC_QUARTER_FRAME : UInt8 = 0xf1
let SONG_POSITION_PTR : UInt8 = 0xf2
let SONG_SELECT : UInt8 = 0xf3
let META_EVENT : UInt8 = 0xff
let MIDI_EOX : UInt8 = 0xf7
let MIDI_CLK : UInt8 = 0xf8
let MIDI_START : UInt8 = 0xfa
let MIDI_CONTINUE : UInt8 = 0xfb
let MIDI_STOP : UInt8 = 0xfc

// RTP MIDI flags in header
let B_FLAG : UInt8 = 0x080
let J_FLAG : UInt8 = 0x040
let Z_FLAG : UInt8 = 0x020
let P_FLAG : UInt8 = 0x010

// RTP MIDI constants
// MIDI Synchronization Source identifier:
//SSRC is a random value generated on initialization

let PROTOCOL_VERSION : UInt32 = 2
// protocol messages
let ACCEPT_INVITATION : UInt16 = 0x4f4b
let INVITATION : UInt16 = 0x494e
let END_SESSION : UInt16 = 0x4259
let SYNCHRONIZATION : UInt16 = 0x434b
let JOURNAL_SYNC : UInt16 = 0x5253
let BITRATE : UInt16 = 0x524c

let APPLE_MIDI : UInt16 = 0xffff
let RTP_MIDI : UInt16 = 0x8061

// bits in the ProTools counter format byte (CC 16)
//
let FMT_TC : UInt8 = 0x1
let FMT_FT_FR : UInt8 = 0x2
let FMT_BAR_BEAT : UInt8 = 0x4

// headers for our SYSEX commands
let twiHeader : [UInt8] = [SYSTEM_EXCLUSIVE,0,0,1,3,2,1]    // text messages to WaspTV
let proToolsHeader : [UInt8] = [SYSTEM_EXCLUSIVE,0x00,0x00,0x66,0x05,0x00,0x11] // PT bar/beat message

enum MENU_TYPE : Int{
case IN_ONLY,OUT_ONLY,IN_AND_OUT
}

