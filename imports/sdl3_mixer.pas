unit sdl3_mixer;

interface

uses
  WinApi.Windows,
  sdl3;

type
  PPUTF8Char = ^PUTF8Char;
  PInt8 = ^Int8;
  PUInt8 = ^UInt8;
  PPUInt8 = ^PUInt8;
  PInt16 = ^Int16;
  PUInt16 = ^UInt16;
  PInt32 = ^Int32;
  PUInt32 = ^UInt32;

const
  { Constants from #define }
  SDL_MIXER_MAJOR_VERSION = 3;
  SDL_MIXER_MINOR_VERSION = 3;
  SDL_MIXER_MICRO_VERSION = 0;
  MIX_PROP_MIXER_DEVICE_NUMBER = 'SDL_mixer.mixer.device';
  MIX_PROP_AUDIO_LOAD_IOSTREAM_POINTER = 'SDL_mixer.audio.load.iostream';
  MIX_PROP_AUDIO_LOAD_CLOSEIO_BOOLEAN = 'SDL_mixer.audio.load.closeio';
  MIX_PROP_AUDIO_LOAD_PREDECODE_BOOLEAN = 'SDL_mixer.audio.load.predecode';
  MIX_PROP_AUDIO_LOAD_PREFERRED_MIXER_POINTER = 'SDL_mixer.audio.load.preferred_mixer';
  MIX_PROP_AUDIO_LOAD_SKIP_METADATA_TAGS_BOOLEAN = 'SDL_mixer.audio.load.skip_metadata_tags';
  MIX_PROP_AUDIO_DECODER_STRING = 'SDL_mixer.audio.decoder';
  MIX_PROP_METADATA_TITLE_STRING = 'SDL_mixer.metadata.title';
  MIX_PROP_METADATA_ARTIST_STRING = 'SDL_mixer.metadata.artist';
  MIX_PROP_METADATA_ALBUM_STRING = 'SDL_mixer.metadata.album';
  MIX_PROP_METADATA_COPYRIGHT_STRING = 'SDL_mixer.metadata.copyright';
  MIX_PROP_METADATA_TRACK_NUMBER = 'SDL_mixer.metadata.track';
  MIX_PROP_METADATA_TOTAL_TRACKS_NUMBER = 'SDL_mixer.metadata.total_tracks';
  MIX_PROP_METADATA_YEAR_NUMBER = 'SDL_mixer.metadata.year';
  MIX_PROP_METADATA_DURATION_FRAMES_NUMBER = 'SDL_mixer.metadata.duration_frames';
  MIX_PROP_METADATA_DURATION_INFINITE_BOOLEAN = 'SDL_mixer.metadata.duration_infinite';
  MIX_DURATION_UNKNOWN = -1;
  MIX_DURATION_INFINITE = -2;
  MIX_PROP_PLAY_LOOPS_NUMBER = 'SDL_mixer.play.loops';
  MIX_PROP_PLAY_MAX_FRAME_NUMBER = 'SDL_mixer.play.max_frame';
  MIX_PROP_PLAY_MAX_MILLISECONDS_NUMBER = 'SDL_mixer.play.max_milliseconds';
  MIX_PROP_PLAY_START_FRAME_NUMBER = 'SDL_mixer.play.start_frame';
  MIX_PROP_PLAY_START_MILLISECOND_NUMBER = 'SDL_mixer.play.start_millisecond';
  MIX_PROP_PLAY_START_ORDER_NUMBER = 'SDL_mixer.play.start_order';
  MIX_PROP_PLAY_LOOP_START_FRAME_NUMBER = 'SDL_mixer.play.loop_start_frame';
  MIX_PROP_PLAY_LOOP_START_MILLISECOND_NUMBER = 'SDL_mixer.play.loop_start_millisecond';
  MIX_PROP_PLAY_FADE_IN_FRAMES_NUMBER = 'SDL_mixer.play.fade_in_frames';
  MIX_PROP_PLAY_FADE_IN_MILLISECONDS_NUMBER = 'SDL_mixer.play.fade_in_milliseconds';
  MIX_PROP_PLAY_FADE_IN_START_GAIN_FLOAT = 'SDL_mixer.play.fade_in_start_gain';
  MIX_PROP_PLAY_APPEND_SILENCE_FRAMES_NUMBER = 'SDL_mixer.play.append_silence_frames';
  MIX_PROP_PLAY_APPEND_SILENCE_MILLISECONDS_NUMBER = 'SDL_mixer.play.append_silence_milliseconds';
  MIX_PROP_PLAY_HALT_WHEN_EXHAUSTED_BOOLEAN = 'SDL_mixer.play.halt_when_exhausted';

type
  { Forward declarations (opaque types) }
  PMIX_Mixer = ^MIX_Mixer;
  PPMIX_Mixer = ^PMIX_Mixer;
  MIX_Mixer = record end;
  PMIX_Audio = ^MIX_Audio;
  PPMIX_Audio = ^PMIX_Audio;
  MIX_Audio = record end;
  PMIX_Track = ^MIX_Track;
  PPMIX_Track = ^PMIX_Track;
  MIX_Track = record end;
  PMIX_Group = ^MIX_Group;
  PPMIX_Group = ^PMIX_Group;
  MIX_Group = record end;
  PMIX_AudioDecoder = ^MIX_AudioDecoder;
  PPMIX_AudioDecoder = ^PMIX_AudioDecoder;
  MIX_AudioDecoder = record end;

type
  PMIX_StereoGains = ^MIX_StereoGains;
  PPMIX_StereoGains = ^PMIX_StereoGains;
  MIX_StereoGains = record
    left: Single;
    right: Single;
  end;
  
  PMIX_Point3D = ^MIX_Point3D;
  PPMIX_Point3D = ^PMIX_Point3D;
  MIX_Point3D = record
    x: Single;
    y: Single;
    z: Single;
  end;
  
  
  MIX_TrackStoppedCallback = procedure(const Auserdata: Pointer; const Atrack: PMIX_Track);
  PMIX_TrackStoppedCallback = ^MIX_TrackStoppedCallback;
  MIX_TrackMixCallback = procedure(const Auserdata: Pointer; const Atrack: PMIX_Track; const Aspec: PSDL_AudioSpec; const Apcm: PSingle; const Asamples: Integer);
  PMIX_TrackMixCallback = ^MIX_TrackMixCallback;
  MIX_GroupMixCallback = procedure(const Auserdata: Pointer; const Agroup: PMIX_Group; const Aspec: PSDL_AudioSpec; const Apcm: PSingle; const Asamples: Integer);
  PMIX_GroupMixCallback = ^MIX_GroupMixCallback;
  MIX_PostMixCallback = procedure(const Auserdata: Pointer; const Amixer: PMIX_Mixer; const Aspec: PSDL_AudioSpec; const Apcm: PSingle; const Asamples: Integer);
  PMIX_PostMixCallback = ^MIX_PostMixCallback;
  

var
  MIX_Version: function(): Integer;
  MIX_Init: function(): Boolean;
  MIX_Quit: procedure();
  MIX_GetNumAudioDecoders: function(): Integer;
  MIX_GetAudioDecoder: function(const Aindex: Integer): PUTF8Char;
  MIX_CreateMixerDevice: function(const Adevid: SDL_AudioDeviceID; const Aspec: PSDL_AudioSpec): PMIX_Mixer;
  MIX_CreateMixer: function(const Aspec: PSDL_AudioSpec): PMIX_Mixer;
  MIX_DestroyMixer: procedure(const Amixer: PMIX_Mixer);
  MIX_GetMixerProperties: function(const Amixer: PMIX_Mixer): SDL_PropertiesID;
  MIX_GetMixerFormat: function(const Amixer: PMIX_Mixer; const Aspec: PSDL_AudioSpec): Boolean;
  MIX_LockMixer: procedure(const Amixer: PMIX_Mixer);
  MIX_UnlockMixer: procedure(const Amixer: PMIX_Mixer);
  MIX_LoadAudio_IO: function(const Amixer: PMIX_Mixer; const Aio: PSDL_IOStream; const Apredecode: Boolean; const Acloseio: Boolean): PMIX_Audio;
  MIX_LoadAudio: function(const Amixer: PMIX_Mixer; const Apath: PUTF8Char; const Apredecode: Boolean): PMIX_Audio;
  MIX_LoadAudioNoCopy: function(const Amixer: PMIX_Mixer; const Adata: Pointer; const Adatalen: NativeUInt; const Afree_when_done: Boolean): PMIX_Audio;
  MIX_LoadAudioWithProperties: function(const Aprops: SDL_PropertiesID): PMIX_Audio;
  MIX_LoadRawAudio_IO: function(const Amixer: PMIX_Mixer; const Aio: PSDL_IOStream; const Aspec: PSDL_AudioSpec; const Acloseio: Boolean): PMIX_Audio;
  MIX_LoadRawAudio: function(const Amixer: PMIX_Mixer; const Adata: Pointer; const Adatalen: NativeUInt; const Aspec: PSDL_AudioSpec): PMIX_Audio;
  MIX_LoadRawAudioNoCopy: function(const Amixer: PMIX_Mixer; const Adata: Pointer; const Adatalen: NativeUInt; const Aspec: PSDL_AudioSpec; const Afree_when_done: Boolean): PMIX_Audio;
  MIX_CreateSineWaveAudio: function(const Amixer: PMIX_Mixer; const Ahz: Integer; const Aamplitude: Single; const Ams: Int64): PMIX_Audio;
  MIX_GetAudioProperties: function(const Aaudio: PMIX_Audio): SDL_PropertiesID;
  MIX_GetAudioDuration: function(const Aaudio: PMIX_Audio): Int64;
  MIX_GetAudioFormat: function(const Aaudio: PMIX_Audio; const Aspec: PSDL_AudioSpec): Boolean;
  MIX_DestroyAudio: procedure(const Aaudio: PMIX_Audio);
  MIX_CreateTrack: function(const Amixer: PMIX_Mixer): PMIX_Track;
  MIX_DestroyTrack: procedure(const Atrack: PMIX_Track);
  MIX_GetTrackProperties: function(const Atrack: PMIX_Track): SDL_PropertiesID;
  MIX_GetTrackMixer: function(const Atrack: PMIX_Track): PMIX_Mixer;
  MIX_SetTrackAudio: function(const Atrack: PMIX_Track; const Aaudio: PMIX_Audio): Boolean;
  MIX_SetTrackAudioStream: function(const Atrack: PMIX_Track; const Astream: PSDL_AudioStream): Boolean;
  MIX_SetTrackIOStream: function(const Atrack: PMIX_Track; const Aio: PSDL_IOStream; const Acloseio: Boolean): Boolean;
  MIX_SetTrackRawIOStream: function(const Atrack: PMIX_Track; const Aio: PSDL_IOStream; const Aspec: PSDL_AudioSpec; const Acloseio: Boolean): Boolean;
  MIX_TagTrack: function(const Atrack: PMIX_Track; const Atag: PUTF8Char): Boolean;
  MIX_UntagTrack: procedure(const Atrack: PMIX_Track; const Atag: PUTF8Char);
  MIX_GetTrackTags: function(const Atrack: PMIX_Track; const Acount: PInteger): PPUTF8Char;
  MIX_GetTaggedTracks: function(const Amixer: PMIX_Mixer; const Atag: PUTF8Char; const Acount: PInteger): PPMIX_Track;
  MIX_SetTrackPlaybackPosition: function(const Atrack: PMIX_Track; const Aframes: Int64): Boolean;
  MIX_GetTrackPlaybackPosition: function(const Atrack: PMIX_Track): Int64;
  MIX_GetTrackFadeFrames: function(const Atrack: PMIX_Track): Int64;
  MIX_GetTrackLoops: function(const Atrack: PMIX_Track): Integer;
  MIX_SetTrackLoops: function(const Atrack: PMIX_Track; const Anum_loops: Integer): Boolean;
  MIX_GetTrackAudio: function(const Atrack: PMIX_Track): PMIX_Audio;
  MIX_GetTrackAudioStream: function(const Atrack: PMIX_Track): PSDL_AudioStream;
  MIX_GetTrackRemaining: function(const Atrack: PMIX_Track): Int64;
  MIX_TrackMSToFrames: function(const Atrack: PMIX_Track; const Ams: Int64): Int64;
  MIX_TrackFramesToMS: function(const Atrack: PMIX_Track; const Aframes: Int64): Int64;
  MIX_AudioMSToFrames: function(const Aaudio: PMIX_Audio; const Ams: Int64): Int64;
  MIX_AudioFramesToMS: function(const Aaudio: PMIX_Audio; const Aframes: Int64): Int64;
  MIX_MSToFrames: function(const Asample_rate: Integer; const Ams: Int64): Int64;
  MIX_FramesToMS: function(const Asample_rate: Integer; const Aframes: Int64): Int64;
  MIX_PlayTrack: function(const Atrack: PMIX_Track; const Aoptions: SDL_PropertiesID): Boolean;
  MIX_PlayTag: function(const Amixer: PMIX_Mixer; const Atag: PUTF8Char; const Aoptions: SDL_PropertiesID): Boolean;
  MIX_PlayAudio: function(const Amixer: PMIX_Mixer; const Aaudio: PMIX_Audio): Boolean;
  MIX_StopTrack: function(const Atrack: PMIX_Track; const Afade_out_frames: Int64): Boolean;
  MIX_StopAllTracks: function(const Amixer: PMIX_Mixer; const Afade_out_ms: Int64): Boolean;
  MIX_StopTag: function(const Amixer: PMIX_Mixer; const Atag: PUTF8Char; const Afade_out_ms: Int64): Boolean;
  MIX_PauseTrack: function(const Atrack: PMIX_Track): Boolean;
  MIX_PauseAllTracks: function(const Amixer: PMIX_Mixer): Boolean;
  MIX_PauseTag: function(const Amixer: PMIX_Mixer; const Atag: PUTF8Char): Boolean;
  MIX_ResumeTrack: function(const Atrack: PMIX_Track): Boolean;
  MIX_ResumeAllTracks: function(const Amixer: PMIX_Mixer): Boolean;
  MIX_ResumeTag: function(const Amixer: PMIX_Mixer; const Atag: PUTF8Char): Boolean;
  MIX_TrackPlaying: function(const Atrack: PMIX_Track): Boolean;
  MIX_TrackPaused: function(const Atrack: PMIX_Track): Boolean;
  MIX_SetMixerGain: function(const Amixer: PMIX_Mixer; const Again: Single): Boolean;
  MIX_GetMixerGain: function(const Amixer: PMIX_Mixer): Single;
  MIX_SetTrackGain: function(const Atrack: PMIX_Track; const Again: Single): Boolean;
  MIX_GetTrackGain: function(const Atrack: PMIX_Track): Single;
  MIX_SetTagGain: function(const Amixer: PMIX_Mixer; const Atag: PUTF8Char; const Again: Single): Boolean;
  MIX_SetMixerFrequencyRatio: function(const Amixer: PMIX_Mixer; const Aratio: Single): Boolean;
  MIX_GetMixerFrequencyRatio: function(const Amixer: PMIX_Mixer): Single;
  MIX_SetTrackFrequencyRatio: function(const Atrack: PMIX_Track; const Aratio: Single): Boolean;
  MIX_GetTrackFrequencyRatio: function(const Atrack: PMIX_Track): Single;
  MIX_SetTrackOutputChannelMap: function(const Atrack: PMIX_Track; const Achmap: PInteger; const Acount: Integer): Boolean;
  MIX_SetTrackStereo: function(const Atrack: PMIX_Track; const Agains: PMIX_StereoGains): Boolean;
  MIX_SetTrack3DPosition: function(const Atrack: PMIX_Track; const Aposition: PMIX_Point3D): Boolean;
  MIX_GetTrack3DPosition: function(const Atrack: PMIX_Track; const Aposition: PMIX_Point3D): Boolean;
  MIX_CreateGroup: function(const Amixer: PMIX_Mixer): PMIX_Group;
  MIX_DestroyGroup: procedure(const Agroup: PMIX_Group);
  MIX_GetGroupProperties: function(const Agroup: PMIX_Group): SDL_PropertiesID;
  MIX_GetGroupMixer: function(const Agroup: PMIX_Group): PMIX_Mixer;
  MIX_SetTrackGroup: function(const Atrack: PMIX_Track; const Agroup: PMIX_Group): Boolean;
  MIX_SetTrackStoppedCallback: function(const Atrack: PMIX_Track; const Acb: MIX_TrackStoppedCallback; const Auserdata: Pointer): Boolean;
  MIX_SetTrackRawCallback: function(const Atrack: PMIX_Track; const Acb: MIX_TrackMixCallback; const Auserdata: Pointer): Boolean;
  MIX_SetTrackCookedCallback: function(const Atrack: PMIX_Track; const Acb: MIX_TrackMixCallback; const Auserdata: Pointer): Boolean;
  MIX_SetGroupPostMixCallback: function(const Agroup: PMIX_Group; const Acb: MIX_GroupMixCallback; const Auserdata: Pointer): Boolean;
  MIX_SetPostMixCallback: function(const Amixer: PMIX_Mixer; const Acb: MIX_PostMixCallback; const Auserdata: Pointer): Boolean;
  MIX_Generate: function(const Amixer: PMIX_Mixer; const Abuffer: Pointer; const Abuflen: Integer): Integer;
  MIX_CreateAudioDecoder: function(const Apath: PUTF8Char; const Aprops: SDL_PropertiesID): PMIX_AudioDecoder;
  MIX_CreateAudioDecoder_IO: function(const Aio: PSDL_IOStream; const Acloseio: Boolean; const Aprops: SDL_PropertiesID): PMIX_AudioDecoder;
  MIX_DestroyAudioDecoder: procedure(const Aaudiodecoder: PMIX_AudioDecoder);
  MIX_GetAudioDecoderProperties: function(const Aaudiodecoder: PMIX_AudioDecoder): SDL_PropertiesID;
  MIX_GetAudioDecoderFormat: function(const Aaudiodecoder: PMIX_AudioDecoder; const Aspec: PSDL_AudioSpec): Boolean;
  MIX_DecodeAudio: function(const Aaudiodecoder: PMIX_AudioDecoder; const Abuffer: Pointer; const Abuflen: Integer; const Aspec: PSDL_AudioSpec): Integer;

implementation

uses
  Dlluminator;

{$R sdl3_mixer.res}


const
  CDllName = 'sdl3_mixer.dll';
  CResName = 'rac670dda8a39422393c0d91332fc0942';

var
  GDllHandle: THandle = 0;

procedure BindExports();
begin
  RegisterDllData(CDllName, CResName);
  GDllHandle := Dlluminator.LoadLibrary(CDllName);
  if GDllHandle = 0 then
    Exit;
  @MIX_Version := GetProcAddress(GDllHandle, 'MIX_Version');
  @MIX_Init := GetProcAddress(GDllHandle, 'MIX_Init');
  @MIX_Quit := GetProcAddress(GDllHandle, 'MIX_Quit');
  @MIX_GetNumAudioDecoders := GetProcAddress(GDllHandle, 'MIX_GetNumAudioDecoders');
  @MIX_GetAudioDecoder := GetProcAddress(GDllHandle, 'MIX_GetAudioDecoder');
  @MIX_CreateMixerDevice := GetProcAddress(GDllHandle, 'MIX_CreateMixerDevice');
  @MIX_CreateMixer := GetProcAddress(GDllHandle, 'MIX_CreateMixer');
  @MIX_DestroyMixer := GetProcAddress(GDllHandle, 'MIX_DestroyMixer');
  @MIX_GetMixerProperties := GetProcAddress(GDllHandle, 'MIX_GetMixerProperties');
  @MIX_GetMixerFormat := GetProcAddress(GDllHandle, 'MIX_GetMixerFormat');
  @MIX_LockMixer := GetProcAddress(GDllHandle, 'MIX_LockMixer');
  @MIX_UnlockMixer := GetProcAddress(GDllHandle, 'MIX_UnlockMixer');
  @MIX_LoadAudio_IO := GetProcAddress(GDllHandle, 'MIX_LoadAudio_IO');
  @MIX_LoadAudio := GetProcAddress(GDllHandle, 'MIX_LoadAudio');
  @MIX_LoadAudioNoCopy := GetProcAddress(GDllHandle, 'MIX_LoadAudioNoCopy');
  @MIX_LoadAudioWithProperties := GetProcAddress(GDllHandle, 'MIX_LoadAudioWithProperties');
  @MIX_LoadRawAudio_IO := GetProcAddress(GDllHandle, 'MIX_LoadRawAudio_IO');
  @MIX_LoadRawAudio := GetProcAddress(GDllHandle, 'MIX_LoadRawAudio');
  @MIX_LoadRawAudioNoCopy := GetProcAddress(GDllHandle, 'MIX_LoadRawAudioNoCopy');
  @MIX_CreateSineWaveAudio := GetProcAddress(GDllHandle, 'MIX_CreateSineWaveAudio');
  @MIX_GetAudioProperties := GetProcAddress(GDllHandle, 'MIX_GetAudioProperties');
  @MIX_GetAudioDuration := GetProcAddress(GDllHandle, 'MIX_GetAudioDuration');
  @MIX_GetAudioFormat := GetProcAddress(GDllHandle, 'MIX_GetAudioFormat');
  @MIX_DestroyAudio := GetProcAddress(GDllHandle, 'MIX_DestroyAudio');
  @MIX_CreateTrack := GetProcAddress(GDllHandle, 'MIX_CreateTrack');
  @MIX_DestroyTrack := GetProcAddress(GDllHandle, 'MIX_DestroyTrack');
  @MIX_GetTrackProperties := GetProcAddress(GDllHandle, 'MIX_GetTrackProperties');
  @MIX_GetTrackMixer := GetProcAddress(GDllHandle, 'MIX_GetTrackMixer');
  @MIX_SetTrackAudio := GetProcAddress(GDllHandle, 'MIX_SetTrackAudio');
  @MIX_SetTrackAudioStream := GetProcAddress(GDllHandle, 'MIX_SetTrackAudioStream');
  @MIX_SetTrackIOStream := GetProcAddress(GDllHandle, 'MIX_SetTrackIOStream');
  @MIX_SetTrackRawIOStream := GetProcAddress(GDllHandle, 'MIX_SetTrackRawIOStream');
  @MIX_TagTrack := GetProcAddress(GDllHandle, 'MIX_TagTrack');
  @MIX_UntagTrack := GetProcAddress(GDllHandle, 'MIX_UntagTrack');
  @MIX_GetTrackTags := GetProcAddress(GDllHandle, 'MIX_GetTrackTags');
  @MIX_GetTaggedTracks := GetProcAddress(GDllHandle, 'MIX_GetTaggedTracks');
  @MIX_SetTrackPlaybackPosition := GetProcAddress(GDllHandle, 'MIX_SetTrackPlaybackPosition');
  @MIX_GetTrackPlaybackPosition := GetProcAddress(GDllHandle, 'MIX_GetTrackPlaybackPosition');
  @MIX_GetTrackFadeFrames := GetProcAddress(GDllHandle, 'MIX_GetTrackFadeFrames');
  @MIX_GetTrackLoops := GetProcAddress(GDllHandle, 'MIX_GetTrackLoops');
  @MIX_SetTrackLoops := GetProcAddress(GDllHandle, 'MIX_SetTrackLoops');
  @MIX_GetTrackAudio := GetProcAddress(GDllHandle, 'MIX_GetTrackAudio');
  @MIX_GetTrackAudioStream := GetProcAddress(GDllHandle, 'MIX_GetTrackAudioStream');
  @MIX_GetTrackRemaining := GetProcAddress(GDllHandle, 'MIX_GetTrackRemaining');
  @MIX_TrackMSToFrames := GetProcAddress(GDllHandle, 'MIX_TrackMSToFrames');
  @MIX_TrackFramesToMS := GetProcAddress(GDllHandle, 'MIX_TrackFramesToMS');
  @MIX_AudioMSToFrames := GetProcAddress(GDllHandle, 'MIX_AudioMSToFrames');
  @MIX_AudioFramesToMS := GetProcAddress(GDllHandle, 'MIX_AudioFramesToMS');
  @MIX_MSToFrames := GetProcAddress(GDllHandle, 'MIX_MSToFrames');
  @MIX_FramesToMS := GetProcAddress(GDllHandle, 'MIX_FramesToMS');
  @MIX_PlayTrack := GetProcAddress(GDllHandle, 'MIX_PlayTrack');
  @MIX_PlayTag := GetProcAddress(GDllHandle, 'MIX_PlayTag');
  @MIX_PlayAudio := GetProcAddress(GDllHandle, 'MIX_PlayAudio');
  @MIX_StopTrack := GetProcAddress(GDllHandle, 'MIX_StopTrack');
  @MIX_StopAllTracks := GetProcAddress(GDllHandle, 'MIX_StopAllTracks');
  @MIX_StopTag := GetProcAddress(GDllHandle, 'MIX_StopTag');
  @MIX_PauseTrack := GetProcAddress(GDllHandle, 'MIX_PauseTrack');
  @MIX_PauseAllTracks := GetProcAddress(GDllHandle, 'MIX_PauseAllTracks');
  @MIX_PauseTag := GetProcAddress(GDllHandle, 'MIX_PauseTag');
  @MIX_ResumeTrack := GetProcAddress(GDllHandle, 'MIX_ResumeTrack');
  @MIX_ResumeAllTracks := GetProcAddress(GDllHandle, 'MIX_ResumeAllTracks');
  @MIX_ResumeTag := GetProcAddress(GDllHandle, 'MIX_ResumeTag');
  @MIX_TrackPlaying := GetProcAddress(GDllHandle, 'MIX_TrackPlaying');
  @MIX_TrackPaused := GetProcAddress(GDllHandle, 'MIX_TrackPaused');
  @MIX_SetMixerGain := GetProcAddress(GDllHandle, 'MIX_SetMixerGain');
  @MIX_GetMixerGain := GetProcAddress(GDllHandle, 'MIX_GetMixerGain');
  @MIX_SetTrackGain := GetProcAddress(GDllHandle, 'MIX_SetTrackGain');
  @MIX_GetTrackGain := GetProcAddress(GDllHandle, 'MIX_GetTrackGain');
  @MIX_SetTagGain := GetProcAddress(GDllHandle, 'MIX_SetTagGain');
  @MIX_SetMixerFrequencyRatio := GetProcAddress(GDllHandle, 'MIX_SetMixerFrequencyRatio');
  @MIX_GetMixerFrequencyRatio := GetProcAddress(GDllHandle, 'MIX_GetMixerFrequencyRatio');
  @MIX_SetTrackFrequencyRatio := GetProcAddress(GDllHandle, 'MIX_SetTrackFrequencyRatio');
  @MIX_GetTrackFrequencyRatio := GetProcAddress(GDllHandle, 'MIX_GetTrackFrequencyRatio');
  @MIX_SetTrackOutputChannelMap := GetProcAddress(GDllHandle, 'MIX_SetTrackOutputChannelMap');
  @MIX_SetTrackStereo := GetProcAddress(GDllHandle, 'MIX_SetTrackStereo');
  @MIX_SetTrack3DPosition := GetProcAddress(GDllHandle, 'MIX_SetTrack3DPosition');
  @MIX_GetTrack3DPosition := GetProcAddress(GDllHandle, 'MIX_GetTrack3DPosition');
  @MIX_CreateGroup := GetProcAddress(GDllHandle, 'MIX_CreateGroup');
  @MIX_DestroyGroup := GetProcAddress(GDllHandle, 'MIX_DestroyGroup');
  @MIX_GetGroupProperties := GetProcAddress(GDllHandle, 'MIX_GetGroupProperties');
  @MIX_GetGroupMixer := GetProcAddress(GDllHandle, 'MIX_GetGroupMixer');
  @MIX_SetTrackGroup := GetProcAddress(GDllHandle, 'MIX_SetTrackGroup');
  @MIX_SetTrackStoppedCallback := GetProcAddress(GDllHandle, 'MIX_SetTrackStoppedCallback');
  @MIX_SetTrackRawCallback := GetProcAddress(GDllHandle, 'MIX_SetTrackRawCallback');
  @MIX_SetTrackCookedCallback := GetProcAddress(GDllHandle, 'MIX_SetTrackCookedCallback');
  @MIX_SetGroupPostMixCallback := GetProcAddress(GDllHandle, 'MIX_SetGroupPostMixCallback');
  @MIX_SetPostMixCallback := GetProcAddress(GDllHandle, 'MIX_SetPostMixCallback');
  @MIX_Generate := GetProcAddress(GDllHandle, 'MIX_Generate');
  @MIX_CreateAudioDecoder := GetProcAddress(GDllHandle, 'MIX_CreateAudioDecoder');
  @MIX_CreateAudioDecoder_IO := GetProcAddress(GDllHandle, 'MIX_CreateAudioDecoder_IO');
  @MIX_DestroyAudioDecoder := GetProcAddress(GDllHandle, 'MIX_DestroyAudioDecoder');
  @MIX_GetAudioDecoderProperties := GetProcAddress(GDllHandle, 'MIX_GetAudioDecoderProperties');
  @MIX_GetAudioDecoderFormat := GetProcAddress(GDllHandle, 'MIX_GetAudioDecoderFormat');
  @MIX_DecodeAudio := GetProcAddress(GDllHandle, 'MIX_DecodeAudio');
end;

procedure UnbindExports();
begin
  @MIX_Version := nil;
  @MIX_Init := nil;
  @MIX_Quit := nil;
  @MIX_GetNumAudioDecoders := nil;
  @MIX_GetAudioDecoder := nil;
  @MIX_CreateMixerDevice := nil;
  @MIX_CreateMixer := nil;
  @MIX_DestroyMixer := nil;
  @MIX_GetMixerProperties := nil;
  @MIX_GetMixerFormat := nil;
  @MIX_LockMixer := nil;
  @MIX_UnlockMixer := nil;
  @MIX_LoadAudio_IO := nil;
  @MIX_LoadAudio := nil;
  @MIX_LoadAudioNoCopy := nil;
  @MIX_LoadAudioWithProperties := nil;
  @MIX_LoadRawAudio_IO := nil;
  @MIX_LoadRawAudio := nil;
  @MIX_LoadRawAudioNoCopy := nil;
  @MIX_CreateSineWaveAudio := nil;
  @MIX_GetAudioProperties := nil;
  @MIX_GetAudioDuration := nil;
  @MIX_GetAudioFormat := nil;
  @MIX_DestroyAudio := nil;
  @MIX_CreateTrack := nil;
  @MIX_DestroyTrack := nil;
  @MIX_GetTrackProperties := nil;
  @MIX_GetTrackMixer := nil;
  @MIX_SetTrackAudio := nil;
  @MIX_SetTrackAudioStream := nil;
  @MIX_SetTrackIOStream := nil;
  @MIX_SetTrackRawIOStream := nil;
  @MIX_TagTrack := nil;
  @MIX_UntagTrack := nil;
  @MIX_GetTrackTags := nil;
  @MIX_GetTaggedTracks := nil;
  @MIX_SetTrackPlaybackPosition := nil;
  @MIX_GetTrackPlaybackPosition := nil;
  @MIX_GetTrackFadeFrames := nil;
  @MIX_GetTrackLoops := nil;
  @MIX_SetTrackLoops := nil;
  @MIX_GetTrackAudio := nil;
  @MIX_GetTrackAudioStream := nil;
  @MIX_GetTrackRemaining := nil;
  @MIX_TrackMSToFrames := nil;
  @MIX_TrackFramesToMS := nil;
  @MIX_AudioMSToFrames := nil;
  @MIX_AudioFramesToMS := nil;
  @MIX_MSToFrames := nil;
  @MIX_FramesToMS := nil;
  @MIX_PlayTrack := nil;
  @MIX_PlayTag := nil;
  @MIX_PlayAudio := nil;
  @MIX_StopTrack := nil;
  @MIX_StopAllTracks := nil;
  @MIX_StopTag := nil;
  @MIX_PauseTrack := nil;
  @MIX_PauseAllTracks := nil;
  @MIX_PauseTag := nil;
  @MIX_ResumeTrack := nil;
  @MIX_ResumeAllTracks := nil;
  @MIX_ResumeTag := nil;
  @MIX_TrackPlaying := nil;
  @MIX_TrackPaused := nil;
  @MIX_SetMixerGain := nil;
  @MIX_GetMixerGain := nil;
  @MIX_SetTrackGain := nil;
  @MIX_GetTrackGain := nil;
  @MIX_SetTagGain := nil;
  @MIX_SetMixerFrequencyRatio := nil;
  @MIX_GetMixerFrequencyRatio := nil;
  @MIX_SetTrackFrequencyRatio := nil;
  @MIX_GetTrackFrequencyRatio := nil;
  @MIX_SetTrackOutputChannelMap := nil;
  @MIX_SetTrackStereo := nil;
  @MIX_SetTrack3DPosition := nil;
  @MIX_GetTrack3DPosition := nil;
  @MIX_CreateGroup := nil;
  @MIX_DestroyGroup := nil;
  @MIX_GetGroupProperties := nil;
  @MIX_GetGroupMixer := nil;
  @MIX_SetTrackGroup := nil;
  @MIX_SetTrackStoppedCallback := nil;
  @MIX_SetTrackRawCallback := nil;
  @MIX_SetTrackCookedCallback := nil;
  @MIX_SetGroupPostMixCallback := nil;
  @MIX_SetPostMixCallback := nil;
  @MIX_Generate := nil;
  @MIX_CreateAudioDecoder := nil;
  @MIX_CreateAudioDecoder_IO := nil;
  @MIX_DestroyAudioDecoder := nil;
  @MIX_GetAudioDecoderProperties := nil;
  @MIX_GetAudioDecoderFormat := nil;
  @MIX_DecodeAudio := nil;
  if GDllHandle <> 0 then
  begin
    FreeLibrary(GDllHandle);
    GDllHandle := 0;
  end;
end;

initialization
  BindExports();

finalization
  UnbindExports();

end.
