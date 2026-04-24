unit sdl3_image;

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
  SDL_IMAGE_MAJOR_VERSION = 3;
  SDL_IMAGE_MINOR_VERSION = 5;
  SDL_IMAGE_MICRO_VERSION = 0;
  IMG_PROP_ANIMATION_ENCODER_CREATE_FILENAME_STRING = 'SDL_image.animation_encoder.create.filename';
  IMG_PROP_ANIMATION_ENCODER_CREATE_IOSTREAM_POINTER = 'SDL_image.animation_encoder.create.iostream';
  IMG_PROP_ANIMATION_ENCODER_CREATE_IOSTREAM_AUTOCLOSE_BOOLEAN = 'SDL_image.animation_encoder.create.iostream.autoclose';
  IMG_PROP_ANIMATION_ENCODER_CREATE_TYPE_STRING = 'SDL_image.animation_encoder.create.type';
  IMG_PROP_ANIMATION_ENCODER_CREATE_QUALITY_NUMBER = 'SDL_image.animation_encoder.create.quality';
  IMG_PROP_ANIMATION_ENCODER_CREATE_TIMEBASE_NUMERATOR_NUMBER = 'SDL_image.animation_encoder.create.timebase.numerator';
  IMG_PROP_ANIMATION_ENCODER_CREATE_TIMEBASE_DENOMINATOR_NUMBER = 'SDL_image.animation_encoder.create.timebase.denominator';
  IMG_PROP_ANIMATION_ENCODER_CREATE_AVIF_MAX_THREADS_NUMBER = 'SDL_image.animation_encoder.create.avif.max_threads';
  IMG_PROP_ANIMATION_ENCODER_CREATE_AVIF_KEYFRAME_INTERVAL_NUMBER = 'SDL_image.animation_encoder.create.avif.keyframe_interval';
  IMG_PROP_ANIMATION_ENCODER_CREATE_GIF_USE_LUT_BOOLEAN = 'SDL_image.animation_encoder.create.gif.use_lut';
  IMG_PROP_ANIMATION_DECODER_CREATE_FILENAME_STRING = 'SDL_image.animation_decoder.create.filename';
  IMG_PROP_ANIMATION_DECODER_CREATE_IOSTREAM_POINTER = 'SDL_image.animation_decoder.create.iostream';
  IMG_PROP_ANIMATION_DECODER_CREATE_IOSTREAM_AUTOCLOSE_BOOLEAN = 'SDL_image.animation_decoder.create.iostream.autoclose';
  IMG_PROP_ANIMATION_DECODER_CREATE_TYPE_STRING = 'SDL_image.animation_decoder.create.type';
  IMG_PROP_ANIMATION_DECODER_CREATE_TIMEBASE_NUMERATOR_NUMBER = 'SDL_image.animation_decoder.create.timebase.numerator';
  IMG_PROP_ANIMATION_DECODER_CREATE_TIMEBASE_DENOMINATOR_NUMBER = 'SDL_image.animation_decoder.create.timebase.denominator';
  IMG_PROP_ANIMATION_DECODER_CREATE_AVIF_MAX_THREADS_NUMBER = 'SDL_image.animation_decoder.create.avif.max_threads';
  IMG_PROP_ANIMATION_DECODER_CREATE_AVIF_ALLOW_INCREMENTAL_BOOLEAN = 'SDL_image.animation_decoder.create.avif.allow_incremental';
  IMG_PROP_ANIMATION_DECODER_CREATE_AVIF_ALLOW_PROGRESSIVE_BOOLEAN = 'SDL_image.animation_decoder.create.avif.allow_progressive';
  IMG_PROP_ANIMATION_DECODER_CREATE_GIF_TRANSPARENT_COLOR_INDEX_NUMBER = 'SDL_image.animation_encoder.create.gif.transparent_color_index';
  IMG_PROP_ANIMATION_DECODER_CREATE_GIF_NUM_COLORS_NUMBER = 'SDL_image.animation_encoder.create.gif.num_colors';
  IMG_PROP_METADATA_IGNORE_PROPS_BOOLEAN = 'SDL_image.metadata.ignore_props';
  IMG_PROP_METADATA_DESCRIPTION_STRING = 'SDL_image.metadata.description';
  IMG_PROP_METADATA_COPYRIGHT_STRING = 'SDL_image.metadata.copyright';
  IMG_PROP_METADATA_TITLE_STRING = 'SDL_image.metadata.title';
  IMG_PROP_METADATA_AUTHOR_STRING = 'SDL_image.metadata.author';
  IMG_PROP_METADATA_CREATION_TIME_STRING = 'SDL_image.metadata.creation_time';
  IMG_PROP_METADATA_FRAME_COUNT_NUMBER = 'SDL_image.metadata.frame_count';
  IMG_PROP_METADATA_LOOP_COUNT_NUMBER = 'SDL_image.metadata.loop_count';

type
  { Forward declarations (opaque types) }
  PIMG_AnimationEncoder = ^IMG_AnimationEncoder;
  PPIMG_AnimationEncoder = ^PIMG_AnimationEncoder;
  IMG_AnimationEncoder = record end;
  PIMG_AnimationDecoder = ^IMG_AnimationDecoder;
  PPIMG_AnimationDecoder = ^PIMG_AnimationDecoder;
  IMG_AnimationDecoder = record end;

type
  IMG_AnimationDecoderStatus = Cardinal;
  PIMG_AnimationDecoderStatus = ^IMG_AnimationDecoderStatus;

const
  { IMG_AnimationDecoderStatus }
  IMG_DECODER_STATUS_INVALID = 1;
  IMG_DECODER_STATUS_OK = 2;
  IMG_DECODER_STATUS_FAILED = 3;
  IMG_DECODER_STATUS_COMPLETE = 4;
  
type
  PIMG_Animation = ^IMG_Animation;
  PPIMG_Animation = ^PIMG_Animation;
  IMG_Animation = record
    w: Integer;
    h: Integer;
    count: Integer;
    frames: PPSDL_Surface;
    delays: PInteger;
  end;
  
  
  

var
  IMG_Version: function(): Integer;
  IMG_Load: function(const Afile: PUTF8Char): PSDL_Surface;
  IMG_Load_IO: function(const Asrc: PSDL_IOStream; const Acloseio: Boolean): PSDL_Surface;
  IMG_LoadTyped_IO: function(const Asrc: PSDL_IOStream; const Acloseio: Boolean; const Atype: PUTF8Char): PSDL_Surface;
  IMG_LoadTexture: function(const Arenderer: PSDL_Renderer; const Afile: PUTF8Char): PSDL_Texture;
  IMG_LoadTexture_IO: function(const Arenderer: PSDL_Renderer; const Asrc: PSDL_IOStream; const Acloseio: Boolean): PSDL_Texture;
  IMG_LoadTextureTyped_IO: function(const Arenderer: PSDL_Renderer; const Asrc: PSDL_IOStream; const Acloseio: Boolean; const Atype: PUTF8Char): PSDL_Texture;
  IMG_LoadGPUTexture: function(const Adevice: PSDL_GPUDevice; const Acopy_pass: PSDL_GPUCopyPass; const Afile: PUTF8Char; const Awidth: PInteger; const Aheight: PInteger): PSDL_GPUTexture;
  IMG_LoadGPUTexture_IO: function(const Adevice: PSDL_GPUDevice; const Acopy_pass: PSDL_GPUCopyPass; const Asrc: PSDL_IOStream; const Acloseio: Boolean; const Awidth: PInteger; const Aheight: PInteger): PSDL_GPUTexture;
  IMG_LoadGPUTextureTyped_IO: function(const Adevice: PSDL_GPUDevice; const Acopy_pass: PSDL_GPUCopyPass; const Asrc: PSDL_IOStream; const Acloseio: Boolean; const Atype: PUTF8Char; const Awidth: PInteger; const Aheight: PInteger): PSDL_GPUTexture;
  IMG_GetClipboardImage: function(): PSDL_Surface;
  IMG_isANI: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isAVIF: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isCUR: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isBMP: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isGIF: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isICO: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isJPG: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isJXL: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isLBM: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isPCX: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isPNG: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isPNM: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isQOI: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isSVG: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isTIF: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isWEBP: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isXCF: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isXPM: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_isXV: function(const Asrc: PSDL_IOStream): Boolean;
  IMG_LoadAVIF_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadBMP_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadCUR_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadGIF_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadICO_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadJPG_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadJXL_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadLBM_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadPCX_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadPNG_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadPNM_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadSVG_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadSizedSVG_IO: function(const Asrc: PSDL_IOStream; const Awidth: Integer; const Aheight: Integer): PSDL_Surface;
  IMG_LoadQOI_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadTGA_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadTIF_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadWEBP_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadXCF_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadXPM_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_LoadXV_IO: function(const Asrc: PSDL_IOStream): PSDL_Surface;
  IMG_ReadXPMFromArray: function(const Axpm: PPUTF8Char): PSDL_Surface;
  IMG_ReadXPMFromArrayToRGB888: function(const Axpm: PPUTF8Char): PSDL_Surface;
  IMG_Save: function(const Asurface: PSDL_Surface; const Afile: PUTF8Char): Boolean;
  IMG_SaveTyped_IO: function(const Asurface: PSDL_Surface; const Adst: PSDL_IOStream; const Acloseio: Boolean; const Atype: PUTF8Char): Boolean;
  IMG_SaveAVIF: function(const Asurface: PSDL_Surface; const Afile: PUTF8Char; const Aquality: Integer): Boolean;
  IMG_SaveAVIF_IO: function(const Asurface: PSDL_Surface; const Adst: PSDL_IOStream; const Acloseio: Boolean; const Aquality: Integer): Boolean;
  IMG_SaveBMP: function(const Asurface: PSDL_Surface; const Afile: PUTF8Char): Boolean;
  IMG_SaveBMP_IO: function(const Asurface: PSDL_Surface; const Adst: PSDL_IOStream; const Acloseio: Boolean): Boolean;
  IMG_SaveCUR: function(const Asurface: PSDL_Surface; const Afile: PUTF8Char): Boolean;
  IMG_SaveCUR_IO: function(const Asurface: PSDL_Surface; const Adst: PSDL_IOStream; const Acloseio: Boolean): Boolean;
  IMG_SaveGIF: function(const Asurface: PSDL_Surface; const Afile: PUTF8Char): Boolean;
  IMG_SaveGIF_IO: function(const Asurface: PSDL_Surface; const Adst: PSDL_IOStream; const Acloseio: Boolean): Boolean;
  IMG_SaveICO: function(const Asurface: PSDL_Surface; const Afile: PUTF8Char): Boolean;
  IMG_SaveICO_IO: function(const Asurface: PSDL_Surface; const Adst: PSDL_IOStream; const Acloseio: Boolean): Boolean;
  IMG_SaveJPG: function(const Asurface: PSDL_Surface; const Afile: PUTF8Char; const Aquality: Integer): Boolean;
  IMG_SaveJPG_IO: function(const Asurface: PSDL_Surface; const Adst: PSDL_IOStream; const Acloseio: Boolean; const Aquality: Integer): Boolean;
  IMG_SavePNG: function(const Asurface: PSDL_Surface; const Afile: PUTF8Char): Boolean;
  IMG_SavePNG_IO: function(const Asurface: PSDL_Surface; const Adst: PSDL_IOStream; const Acloseio: Boolean): Boolean;
  IMG_SaveTGA: function(const Asurface: PSDL_Surface; const Afile: PUTF8Char): Boolean;
  IMG_SaveTGA_IO: function(const Asurface: PSDL_Surface; const Adst: PSDL_IOStream; const Acloseio: Boolean): Boolean;
  IMG_SaveWEBP: function(const Asurface: PSDL_Surface; const Afile: PUTF8Char; const Aquality: Single): Boolean;
  IMG_SaveWEBP_IO: function(const Asurface: PSDL_Surface; const Adst: PSDL_IOStream; const Acloseio: Boolean; const Aquality: Single): Boolean;
  IMG_LoadAnimation: function(const Afile: PUTF8Char): PIMG_Animation;
  IMG_LoadAnimation_IO: function(const Asrc: PSDL_IOStream; const Acloseio: Boolean): PIMG_Animation;
  IMG_LoadAnimationTyped_IO: function(const Asrc: PSDL_IOStream; const Acloseio: Boolean; const Atype: PUTF8Char): PIMG_Animation;
  IMG_LoadANIAnimation_IO: function(const Asrc: PSDL_IOStream): PIMG_Animation;
  IMG_LoadAPNGAnimation_IO: function(const Asrc: PSDL_IOStream): PIMG_Animation;
  IMG_LoadAVIFAnimation_IO: function(const Asrc: PSDL_IOStream): PIMG_Animation;
  IMG_LoadGIFAnimation_IO: function(const Asrc: PSDL_IOStream): PIMG_Animation;
  IMG_LoadWEBPAnimation_IO: function(const Asrc: PSDL_IOStream): PIMG_Animation;
  IMG_SaveAnimation: function(const Aanim: PIMG_Animation; const Afile: PUTF8Char): Boolean;
  IMG_SaveAnimationTyped_IO: function(const Aanim: PIMG_Animation; const Adst: PSDL_IOStream; const Acloseio: Boolean; const Atype: PUTF8Char): Boolean;
  IMG_SaveANIAnimation_IO: function(const Aanim: PIMG_Animation; const Adst: PSDL_IOStream; const Acloseio: Boolean): Boolean;
  IMG_SaveAPNGAnimation_IO: function(const Aanim: PIMG_Animation; const Adst: PSDL_IOStream; const Acloseio: Boolean): Boolean;
  IMG_SaveAVIFAnimation_IO: function(const Aanim: PIMG_Animation; const Adst: PSDL_IOStream; const Acloseio: Boolean; const Aquality: Integer): Boolean;
  IMG_SaveGIFAnimation_IO: function(const Aanim: PIMG_Animation; const Adst: PSDL_IOStream; const Acloseio: Boolean): Boolean;
  IMG_SaveWEBPAnimation_IO: function(const Aanim: PIMG_Animation; const Adst: PSDL_IOStream; const Acloseio: Boolean; const Aquality: Integer): Boolean;
  IMG_CreateAnimatedCursor: function(const Aanim: PIMG_Animation; const Ahot_x: Integer; const Ahot_y: Integer): PSDL_Cursor;
  IMG_FreeAnimation: procedure(const Aanim: PIMG_Animation);
  IMG_CreateAnimationEncoder: function(const Afile: PUTF8Char): PIMG_AnimationEncoder;
  IMG_CreateAnimationEncoder_IO: function(const Adst: PSDL_IOStream; const Acloseio: Boolean; const Atype: PUTF8Char): PIMG_AnimationEncoder;
  IMG_CreateAnimationEncoderWithProperties: function(const Aprops: SDL_PropertiesID): PIMG_AnimationEncoder;
  IMG_AddAnimationEncoderFrame: function(const Aencoder: PIMG_AnimationEncoder; const Asurface: PSDL_Surface; const Aduration: UInt64): Boolean;
  IMG_CloseAnimationEncoder: function(const Aencoder: PIMG_AnimationEncoder): Boolean;
  IMG_CreateAnimationDecoder: function(const Afile: PUTF8Char): PIMG_AnimationDecoder;
  IMG_CreateAnimationDecoder_IO: function(const Asrc: PSDL_IOStream; const Acloseio: Boolean; const Atype: PUTF8Char): PIMG_AnimationDecoder;
  IMG_CreateAnimationDecoderWithProperties: function(const Aprops: SDL_PropertiesID): PIMG_AnimationDecoder;
  IMG_GetAnimationDecoderProperties: function(const Adecoder: PIMG_AnimationDecoder): SDL_PropertiesID;
  IMG_GetAnimationDecoderFrame: function(const Adecoder: PIMG_AnimationDecoder; const Aframe: PPSDL_Surface; const Aduration: PUInt64): Boolean;
  IMG_GetAnimationDecoderStatus: function(const Adecoder: PIMG_AnimationDecoder): IMG_AnimationDecoderStatus;
  IMG_ResetAnimationDecoder: function(const Adecoder: PIMG_AnimationDecoder): Boolean;
  IMG_CloseAnimationDecoder: function(const Adecoder: PIMG_AnimationDecoder): Boolean;

implementation

uses
  Dlluminator;

{$R sdl3_image.res}


const
  CDllName = 'sdl3_image.dll';
  CResName = 'rac06d3ac51064875aa5b0c4f878b2d68';

var
  GDllHandle: THandle = 0;

procedure BindExports();
begin
  RegisterDllData(CDllName, CResName);
  GDllHandle := Dlluminator.LoadLibrary(CDllName);
  if GDllHandle = 0 then
    Exit;
  @IMG_Version := GetProcAddress(GDllHandle, 'IMG_Version');
  @IMG_Load := GetProcAddress(GDllHandle, 'IMG_Load');
  @IMG_Load_IO := GetProcAddress(GDllHandle, 'IMG_Load_IO');
  @IMG_LoadTyped_IO := GetProcAddress(GDllHandle, 'IMG_LoadTyped_IO');
  @IMG_LoadTexture := GetProcAddress(GDllHandle, 'IMG_LoadTexture');
  @IMG_LoadTexture_IO := GetProcAddress(GDllHandle, 'IMG_LoadTexture_IO');
  @IMG_LoadTextureTyped_IO := GetProcAddress(GDllHandle, 'IMG_LoadTextureTyped_IO');
  @IMG_LoadGPUTexture := GetProcAddress(GDllHandle, 'IMG_LoadGPUTexture');
  @IMG_LoadGPUTexture_IO := GetProcAddress(GDllHandle, 'IMG_LoadGPUTexture_IO');
  @IMG_LoadGPUTextureTyped_IO := GetProcAddress(GDllHandle, 'IMG_LoadGPUTextureTyped_IO');
  @IMG_GetClipboardImage := GetProcAddress(GDllHandle, 'IMG_GetClipboardImage');
  @IMG_isANI := GetProcAddress(GDllHandle, 'IMG_isANI');
  @IMG_isAVIF := GetProcAddress(GDllHandle, 'IMG_isAVIF');
  @IMG_isCUR := GetProcAddress(GDllHandle, 'IMG_isCUR');
  @IMG_isBMP := GetProcAddress(GDllHandle, 'IMG_isBMP');
  @IMG_isGIF := GetProcAddress(GDllHandle, 'IMG_isGIF');
  @IMG_isICO := GetProcAddress(GDllHandle, 'IMG_isICO');
  @IMG_isJPG := GetProcAddress(GDllHandle, 'IMG_isJPG');
  @IMG_isJXL := GetProcAddress(GDllHandle, 'IMG_isJXL');
  @IMG_isLBM := GetProcAddress(GDllHandle, 'IMG_isLBM');
  @IMG_isPCX := GetProcAddress(GDllHandle, 'IMG_isPCX');
  @IMG_isPNG := GetProcAddress(GDllHandle, 'IMG_isPNG');
  @IMG_isPNM := GetProcAddress(GDllHandle, 'IMG_isPNM');
  @IMG_isQOI := GetProcAddress(GDllHandle, 'IMG_isQOI');
  @IMG_isSVG := GetProcAddress(GDllHandle, 'IMG_isSVG');
  @IMG_isTIF := GetProcAddress(GDllHandle, 'IMG_isTIF');
  @IMG_isWEBP := GetProcAddress(GDllHandle, 'IMG_isWEBP');
  @IMG_isXCF := GetProcAddress(GDllHandle, 'IMG_isXCF');
  @IMG_isXPM := GetProcAddress(GDllHandle, 'IMG_isXPM');
  @IMG_isXV := GetProcAddress(GDllHandle, 'IMG_isXV');
  @IMG_LoadAVIF_IO := GetProcAddress(GDllHandle, 'IMG_LoadAVIF_IO');
  @IMG_LoadBMP_IO := GetProcAddress(GDllHandle, 'IMG_LoadBMP_IO');
  @IMG_LoadCUR_IO := GetProcAddress(GDllHandle, 'IMG_LoadCUR_IO');
  @IMG_LoadGIF_IO := GetProcAddress(GDllHandle, 'IMG_LoadGIF_IO');
  @IMG_LoadICO_IO := GetProcAddress(GDllHandle, 'IMG_LoadICO_IO');
  @IMG_LoadJPG_IO := GetProcAddress(GDllHandle, 'IMG_LoadJPG_IO');
  @IMG_LoadJXL_IO := GetProcAddress(GDllHandle, 'IMG_LoadJXL_IO');
  @IMG_LoadLBM_IO := GetProcAddress(GDllHandle, 'IMG_LoadLBM_IO');
  @IMG_LoadPCX_IO := GetProcAddress(GDllHandle, 'IMG_LoadPCX_IO');
  @IMG_LoadPNG_IO := GetProcAddress(GDllHandle, 'IMG_LoadPNG_IO');
  @IMG_LoadPNM_IO := GetProcAddress(GDllHandle, 'IMG_LoadPNM_IO');
  @IMG_LoadSVG_IO := GetProcAddress(GDllHandle, 'IMG_LoadSVG_IO');
  @IMG_LoadSizedSVG_IO := GetProcAddress(GDllHandle, 'IMG_LoadSizedSVG_IO');
  @IMG_LoadQOI_IO := GetProcAddress(GDllHandle, 'IMG_LoadQOI_IO');
  @IMG_LoadTGA_IO := GetProcAddress(GDllHandle, 'IMG_LoadTGA_IO');
  @IMG_LoadTIF_IO := GetProcAddress(GDllHandle, 'IMG_LoadTIF_IO');
  @IMG_LoadWEBP_IO := GetProcAddress(GDllHandle, 'IMG_LoadWEBP_IO');
  @IMG_LoadXCF_IO := GetProcAddress(GDllHandle, 'IMG_LoadXCF_IO');
  @IMG_LoadXPM_IO := GetProcAddress(GDllHandle, 'IMG_LoadXPM_IO');
  @IMG_LoadXV_IO := GetProcAddress(GDllHandle, 'IMG_LoadXV_IO');
  @IMG_ReadXPMFromArray := GetProcAddress(GDllHandle, 'IMG_ReadXPMFromArray');
  @IMG_ReadXPMFromArrayToRGB888 := GetProcAddress(GDllHandle, 'IMG_ReadXPMFromArrayToRGB888');
  @IMG_Save := GetProcAddress(GDllHandle, 'IMG_Save');
  @IMG_SaveTyped_IO := GetProcAddress(GDllHandle, 'IMG_SaveTyped_IO');
  @IMG_SaveAVIF := GetProcAddress(GDllHandle, 'IMG_SaveAVIF');
  @IMG_SaveAVIF_IO := GetProcAddress(GDllHandle, 'IMG_SaveAVIF_IO');
  @IMG_SaveBMP := GetProcAddress(GDllHandle, 'IMG_SaveBMP');
  @IMG_SaveBMP_IO := GetProcAddress(GDllHandle, 'IMG_SaveBMP_IO');
  @IMG_SaveCUR := GetProcAddress(GDllHandle, 'IMG_SaveCUR');
  @IMG_SaveCUR_IO := GetProcAddress(GDllHandle, 'IMG_SaveCUR_IO');
  @IMG_SaveGIF := GetProcAddress(GDllHandle, 'IMG_SaveGIF');
  @IMG_SaveGIF_IO := GetProcAddress(GDllHandle, 'IMG_SaveGIF_IO');
  @IMG_SaveICO := GetProcAddress(GDllHandle, 'IMG_SaveICO');
  @IMG_SaveICO_IO := GetProcAddress(GDllHandle, 'IMG_SaveICO_IO');
  @IMG_SaveJPG := GetProcAddress(GDllHandle, 'IMG_SaveJPG');
  @IMG_SaveJPG_IO := GetProcAddress(GDllHandle, 'IMG_SaveJPG_IO');
  @IMG_SavePNG := GetProcAddress(GDllHandle, 'IMG_SavePNG');
  @IMG_SavePNG_IO := GetProcAddress(GDllHandle, 'IMG_SavePNG_IO');
  @IMG_SaveTGA := GetProcAddress(GDllHandle, 'IMG_SaveTGA');
  @IMG_SaveTGA_IO := GetProcAddress(GDllHandle, 'IMG_SaveTGA_IO');
  @IMG_SaveWEBP := GetProcAddress(GDllHandle, 'IMG_SaveWEBP');
  @IMG_SaveWEBP_IO := GetProcAddress(GDllHandle, 'IMG_SaveWEBP_IO');
  @IMG_LoadAnimation := GetProcAddress(GDllHandle, 'IMG_LoadAnimation');
  @IMG_LoadAnimation_IO := GetProcAddress(GDllHandle, 'IMG_LoadAnimation_IO');
  @IMG_LoadAnimationTyped_IO := GetProcAddress(GDllHandle, 'IMG_LoadAnimationTyped_IO');
  @IMG_LoadANIAnimation_IO := GetProcAddress(GDllHandle, 'IMG_LoadANIAnimation_IO');
  @IMG_LoadAPNGAnimation_IO := GetProcAddress(GDllHandle, 'IMG_LoadAPNGAnimation_IO');
  @IMG_LoadAVIFAnimation_IO := GetProcAddress(GDllHandle, 'IMG_LoadAVIFAnimation_IO');
  @IMG_LoadGIFAnimation_IO := GetProcAddress(GDllHandle, 'IMG_LoadGIFAnimation_IO');
  @IMG_LoadWEBPAnimation_IO := GetProcAddress(GDllHandle, 'IMG_LoadWEBPAnimation_IO');
  @IMG_SaveAnimation := GetProcAddress(GDllHandle, 'IMG_SaveAnimation');
  @IMG_SaveAnimationTyped_IO := GetProcAddress(GDllHandle, 'IMG_SaveAnimationTyped_IO');
  @IMG_SaveANIAnimation_IO := GetProcAddress(GDllHandle, 'IMG_SaveANIAnimation_IO');
  @IMG_SaveAPNGAnimation_IO := GetProcAddress(GDllHandle, 'IMG_SaveAPNGAnimation_IO');
  @IMG_SaveAVIFAnimation_IO := GetProcAddress(GDllHandle, 'IMG_SaveAVIFAnimation_IO');
  @IMG_SaveGIFAnimation_IO := GetProcAddress(GDllHandle, 'IMG_SaveGIFAnimation_IO');
  @IMG_SaveWEBPAnimation_IO := GetProcAddress(GDllHandle, 'IMG_SaveWEBPAnimation_IO');
  @IMG_CreateAnimatedCursor := GetProcAddress(GDllHandle, 'IMG_CreateAnimatedCursor');
  @IMG_FreeAnimation := GetProcAddress(GDllHandle, 'IMG_FreeAnimation');
  @IMG_CreateAnimationEncoder := GetProcAddress(GDllHandle, 'IMG_CreateAnimationEncoder');
  @IMG_CreateAnimationEncoder_IO := GetProcAddress(GDllHandle, 'IMG_CreateAnimationEncoder_IO');
  @IMG_CreateAnimationEncoderWithProperties := GetProcAddress(GDllHandle, 'IMG_CreateAnimationEncoderWithProperties');
  @IMG_AddAnimationEncoderFrame := GetProcAddress(GDllHandle, 'IMG_AddAnimationEncoderFrame');
  @IMG_CloseAnimationEncoder := GetProcAddress(GDllHandle, 'IMG_CloseAnimationEncoder');
  @IMG_CreateAnimationDecoder := GetProcAddress(GDllHandle, 'IMG_CreateAnimationDecoder');
  @IMG_CreateAnimationDecoder_IO := GetProcAddress(GDllHandle, 'IMG_CreateAnimationDecoder_IO');
  @IMG_CreateAnimationDecoderWithProperties := GetProcAddress(GDllHandle, 'IMG_CreateAnimationDecoderWithProperties');
  @IMG_GetAnimationDecoderProperties := GetProcAddress(GDllHandle, 'IMG_GetAnimationDecoderProperties');
  @IMG_GetAnimationDecoderFrame := GetProcAddress(GDllHandle, 'IMG_GetAnimationDecoderFrame');
  @IMG_GetAnimationDecoderStatus := GetProcAddress(GDllHandle, 'IMG_GetAnimationDecoderStatus');
  @IMG_ResetAnimationDecoder := GetProcAddress(GDllHandle, 'IMG_ResetAnimationDecoder');
  @IMG_CloseAnimationDecoder := GetProcAddress(GDllHandle, 'IMG_CloseAnimationDecoder');
end;

procedure UnbindExports();
begin
  @IMG_Version := nil;
  @IMG_Load := nil;
  @IMG_Load_IO := nil;
  @IMG_LoadTyped_IO := nil;
  @IMG_LoadTexture := nil;
  @IMG_LoadTexture_IO := nil;
  @IMG_LoadTextureTyped_IO := nil;
  @IMG_LoadGPUTexture := nil;
  @IMG_LoadGPUTexture_IO := nil;
  @IMG_LoadGPUTextureTyped_IO := nil;
  @IMG_GetClipboardImage := nil;
  @IMG_isANI := nil;
  @IMG_isAVIF := nil;
  @IMG_isCUR := nil;
  @IMG_isBMP := nil;
  @IMG_isGIF := nil;
  @IMG_isICO := nil;
  @IMG_isJPG := nil;
  @IMG_isJXL := nil;
  @IMG_isLBM := nil;
  @IMG_isPCX := nil;
  @IMG_isPNG := nil;
  @IMG_isPNM := nil;
  @IMG_isQOI := nil;
  @IMG_isSVG := nil;
  @IMG_isTIF := nil;
  @IMG_isWEBP := nil;
  @IMG_isXCF := nil;
  @IMG_isXPM := nil;
  @IMG_isXV := nil;
  @IMG_LoadAVIF_IO := nil;
  @IMG_LoadBMP_IO := nil;
  @IMG_LoadCUR_IO := nil;
  @IMG_LoadGIF_IO := nil;
  @IMG_LoadICO_IO := nil;
  @IMG_LoadJPG_IO := nil;
  @IMG_LoadJXL_IO := nil;
  @IMG_LoadLBM_IO := nil;
  @IMG_LoadPCX_IO := nil;
  @IMG_LoadPNG_IO := nil;
  @IMG_LoadPNM_IO := nil;
  @IMG_LoadSVG_IO := nil;
  @IMG_LoadSizedSVG_IO := nil;
  @IMG_LoadQOI_IO := nil;
  @IMG_LoadTGA_IO := nil;
  @IMG_LoadTIF_IO := nil;
  @IMG_LoadWEBP_IO := nil;
  @IMG_LoadXCF_IO := nil;
  @IMG_LoadXPM_IO := nil;
  @IMG_LoadXV_IO := nil;
  @IMG_ReadXPMFromArray := nil;
  @IMG_ReadXPMFromArrayToRGB888 := nil;
  @IMG_Save := nil;
  @IMG_SaveTyped_IO := nil;
  @IMG_SaveAVIF := nil;
  @IMG_SaveAVIF_IO := nil;
  @IMG_SaveBMP := nil;
  @IMG_SaveBMP_IO := nil;
  @IMG_SaveCUR := nil;
  @IMG_SaveCUR_IO := nil;
  @IMG_SaveGIF := nil;
  @IMG_SaveGIF_IO := nil;
  @IMG_SaveICO := nil;
  @IMG_SaveICO_IO := nil;
  @IMG_SaveJPG := nil;
  @IMG_SaveJPG_IO := nil;
  @IMG_SavePNG := nil;
  @IMG_SavePNG_IO := nil;
  @IMG_SaveTGA := nil;
  @IMG_SaveTGA_IO := nil;
  @IMG_SaveWEBP := nil;
  @IMG_SaveWEBP_IO := nil;
  @IMG_LoadAnimation := nil;
  @IMG_LoadAnimation_IO := nil;
  @IMG_LoadAnimationTyped_IO := nil;
  @IMG_LoadANIAnimation_IO := nil;
  @IMG_LoadAPNGAnimation_IO := nil;
  @IMG_LoadAVIFAnimation_IO := nil;
  @IMG_LoadGIFAnimation_IO := nil;
  @IMG_LoadWEBPAnimation_IO := nil;
  @IMG_SaveAnimation := nil;
  @IMG_SaveAnimationTyped_IO := nil;
  @IMG_SaveANIAnimation_IO := nil;
  @IMG_SaveAPNGAnimation_IO := nil;
  @IMG_SaveAVIFAnimation_IO := nil;
  @IMG_SaveGIFAnimation_IO := nil;
  @IMG_SaveWEBPAnimation_IO := nil;
  @IMG_CreateAnimatedCursor := nil;
  @IMG_FreeAnimation := nil;
  @IMG_CreateAnimationEncoder := nil;
  @IMG_CreateAnimationEncoder_IO := nil;
  @IMG_CreateAnimationEncoderWithProperties := nil;
  @IMG_AddAnimationEncoderFrame := nil;
  @IMG_CloseAnimationEncoder := nil;
  @IMG_CreateAnimationDecoder := nil;
  @IMG_CreateAnimationDecoder_IO := nil;
  @IMG_CreateAnimationDecoderWithProperties := nil;
  @IMG_GetAnimationDecoderProperties := nil;
  @IMG_GetAnimationDecoderFrame := nil;
  @IMG_GetAnimationDecoderStatus := nil;
  @IMG_ResetAnimationDecoder := nil;
  @IMG_CloseAnimationDecoder := nil;
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
