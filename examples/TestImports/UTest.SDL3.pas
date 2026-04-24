{===============================================================================
  Dlluminator™ - Win64 Memory DLL Loader

  Copyright © 2025-present tinyBigGAMES™ LLC
  All Rights Reserved.

  See LICENSE for license information
===============================================================================}

unit UTest.SDL3;

interface

procedure TestSDL3(const ANum: Integer);

implementation

uses
  System.SysUtils,
  Dlluminator.Utils,
  sdl3,
  sdl3_image,
  sdl3_mixer;

procedure HsvToRgb(const AH, ASat, AV: Single; var AR, AG, AB: Byte);
var
  LI: Integer;
  LF: Single;
  LP: Single;
  LQ: Single;
  LT: Single;
  LR: Single;
  LG: Single;
  LB: Single;
begin
  LI := Trunc(AH * 6.0);
  LF := AH * 6.0 - LI;
  LP := AV * (1.0 - ASat);
  LQ := AV * (1.0 - LF * ASat);
  LT := AV * (1.0 - (1.0 - LF) * ASat);

  case LI mod 6 of
    0: begin LR := AV; LG := LT; LB := LP; end;
    1: begin LR := LQ; LG := AV; LB := LP; end;
    2: begin LR := LP; LG := AV; LB := LT; end;
    3: begin LR := LP; LG := LQ; LB := AV; end;
    4: begin LR := LT; LG := LP; LB := AV; end;
  else
    begin LR := AV; LG := LP; LB := LQ; end;
  end;

  AR := Trunc(LR * 255.0);
  AG := Trunc(LG * 255.0);
  AB := Trunc(LB * 255.0);
end;

procedure Test01();
const
  CScreenWidth = 1280;
  CScreenHeight = 720;
  CWindowTitle = 'Dlluminator + SDL3 Demo';
var
  LWindow: PSDL_Window;
  LRenderer: PSDL_Renderer;
  LEvent: SDL_Event;
  LRunning: Boolean;
  LHue: Single;
  LLastTime: UInt64;
  LCurrentTime: UInt64;
  LDeltaTime: Single;
  LFrameCount: Integer;
  LFpsTimer: Single;
  LFps: Integer;
  LRectDir: Single;
  LRectX: Single;
  LR: Byte;
  LG: Byte;
  LB: Byte;
  LRect: SDL_FRect;
begin
  LRunning := True;
  LHue := 0.0;
  LFrameCount := 0;
  LFpsTimer := 0.0;
  LRectDir := 1.0;
  LRectX := 100.0;

  if not SDL_Init(SDL_INIT_VIDEO) then
  begin
    SDL_Quit();
    Exit;
  end;

  LWindow := SDL_CreateWindow(CWindowTitle, CScreenWidth, CScreenHeight, 0);
  if LWindow = nil then
  begin
    SDL_Quit();
    Exit;
  end;

  LRenderer := SDL_CreateRenderer(LWindow, nil);
  if LRenderer = nil then
  begin
    SDL_DestroyWindow(LWindow);
    SDL_Quit();
    Exit;
  end;

  LLastTime := SDL_GetPerformanceCounter();

  while LRunning do
  begin
    while SDL_PollEvent(@LEvent) do
    begin
      if LEvent.type_ = SDL_EVENT_QUIT then
        LRunning := False;
      if LEvent.type_ = SDL_EVENT_KEY_DOWN then
      begin
        if LEvent.key.key = SDLK_ESCAPE then
          LRunning := False;
      end;
    end;

    LCurrentTime := SDL_GetPerformanceCounter();
    LDeltaTime := (LCurrentTime - LLastTime) / SDL_GetPerformanceFrequency();
    LLastTime := LCurrentTime;

    LFrameCount := LFrameCount + 1;
    LFpsTimer := LFpsTimer + LDeltaTime;
    if LFpsTimer >= 1.0 then
    begin
      LFps := LFrameCount;
      LFrameCount := 0;
      LFpsTimer := LFpsTimer - 1.0;
      SDL_SetWindowTitle(LWindow, PAnsiChar(AnsiString(Format('%s - FPS: %d', [CWindowTitle, LFps]))));
    end;

    LHue := LHue + LDeltaTime * 0.1;
    if LHue > 1.0 then
      LHue := LHue - 1.0;

    LRectX := LRectX + LRectDir * 200.0 * LDeltaTime;
    if LRectX > (CScreenWidth - 150) then
      LRectDir := -1.0;
    if LRectX < 100.0 then
      LRectDir := 1.0;

    // Cycling background color
    HsvToRgb(LHue, 0.3, 0.2, LR, LG, LB);
    SDL_SetRenderDrawColor(LRenderer, LR, LG, LB, 255);
    SDL_RenderClear(LRenderer);

    // Bouncing rectangle
    HsvToRgb(LHue + 0.5, 0.8, 0.9, LR, LG, LB);
    SDL_SetRenderDrawColor(LRenderer, LR, LG, LB, 255);
    LRect.x := LRectX;
    LRect.y := 300.0;
    LRect.w := 150.0;
    LRect.h := 100.0;
    SDL_RenderFillRect(LRenderer, @LRect);

    // Static red rectangle (top-left)
    SDL_SetRenderDrawColor(LRenderer, 255, 100, 100, 255);
    LRect.x := 50.0;
    LRect.y := 50.0;
    LRect.w := 200.0;
    LRect.h := 150.0;
    SDL_RenderFillRect(LRenderer, @LRect);

    // Static green rectangle (top-right)
    SDL_SetRenderDrawColor(LRenderer, 100, 255, 100, 255);
    LRect.x := CScreenWidth - 250;
    LRect.y := 50.0;
    LRect.w := 200.0;
    LRect.h := 150.0;
    SDL_RenderFillRect(LRenderer, @LRect);

    // Static blue rectangle (bottom-center)
    SDL_SetRenderDrawColor(LRenderer, 100, 100, 255, 255);
    LRect.x := CScreenWidth div 2 - 100;
    LRect.y := CScreenHeight - 200;
    LRect.w := 200.0;
    LRect.h := 150.0;
    SDL_RenderFillRect(LRenderer, @LRect);

    SDL_RenderPresent(LRenderer);
  end;

  SDL_DestroyRenderer(LRenderer);
  SDL_DestroyWindow(LWindow);
  SDL_Quit();
end;

procedure Test02();
const
  CScreenWidth = 1280;
  CScreenHeight = 720;
  CWindowTitle = 'Dlluminator + SDL3_image Demo';
var
  LWindow: PSDL_Window;
  LRenderer: PSDL_Renderer;
  LTexture: PSDL_Texture;
  LEvent: SDL_Event;
  LRunning: Boolean;
  LHue: Single;
  LLastTime: UInt64;
  LCurrentTime: UInt64;
  LDeltaTime: Single;
  LR: Byte;
  LG: Byte;
  LB: Byte;
  LRect: SDL_FRect;
  LTexW: Single;
  LTexH: Single;
begin
  LRunning := True;
  LHue := 0.0;

  if not SDL_Init(SDL_INIT_VIDEO) then
  begin
    WriteLn('failed to init SDL');
    SDL_Quit();
    Exit;
  end;

  LWindow := SDL_CreateWindow(CWindowTitle, CScreenWidth, CScreenHeight, 0);
  if LWindow = nil then
  begin
    WriteLn('failed to create window');
    SDL_Quit();
    Exit;
  end;

  LRenderer := SDL_CreateRenderer(LWindow, nil);
  if LRenderer = nil then
  begin
    WriteLn('failed to create renderer');
    SDL_DestroyWindow(LWindow);
    SDL_Quit();
    Exit;
  end;

  // Load texture using SDL3_image
  LTexture := IMG_LoadTexture(LRenderer, 'res/images/dlluminator.png');
  if LTexture = nil then
  begin
    WriteLn('failed to load image');
    SDL_DestroyRenderer(LRenderer);
    SDL_DestroyWindow(LWindow);
    SDL_Quit();
    Exit;
  end;

  // Get texture dimensions
  SDL_GetTextureSize(LTexture, @LTexW, @LTexH);

  LLastTime := SDL_GetPerformanceCounter();

  while LRunning do
  begin
    while SDL_PollEvent(@LEvent) do
    begin
      if LEvent.type_ = SDL_EVENT_QUIT then
        LRunning := False;
      if LEvent.type_ = SDL_EVENT_KEY_DOWN then
      begin
        if LEvent.key.key = SDLK_ESCAPE then
          LRunning := False;
      end;
    end;

    LCurrentTime := SDL_GetPerformanceCounter();
    LDeltaTime := (LCurrentTime - LLastTime) / SDL_GetPerformanceFrequency();
    LLastTime := LCurrentTime;

    // Animate background hue
    LHue := LHue + LDeltaTime * 0.1;
    if LHue > 1.0 then
      LHue := LHue - 1.0;

    // Clear with animated background color
    HsvToRgb(LHue, 0.3, 0.2, LR, LG, LB);
    SDL_SetRenderDrawColor(LRenderer, LR, LG, LB, 255);
    SDL_RenderClear(LRenderer);

    // Render texture centered on screen
    LRect.x := (CScreenWidth - LTexW) / 2.0;
    LRect.y := (CScreenHeight - LTexH) / 2.0;
    LRect.w := LTexW;
    LRect.h := LTexH;
    SDL_RenderTexture(LRenderer, LTexture, nil, @LRect);

    SDL_RenderPresent(LRenderer);
  end;

  SDL_DestroyTexture(LTexture);
  SDL_DestroyRenderer(LRenderer);
  SDL_DestroyWindow(LWindow);
  SDL_Quit();
end;

procedure Test03();
const
  CScreenWidth = 800;
  CScreenHeight = 600;
  CWindowTitle = 'Dlluminator + SDL3_Mixer Demo';
var
  LWindow: PSDL_Window;
  LRenderer: PSDL_Renderer;
  LMixer: PMIX_Mixer;
  LAudio: PMIX_Audio;
  LTrack: PMIX_Track;
  LProps: SDL_PropertiesID;
  LEvent: SDL_Event;
  LRunning: Boolean;
begin
  LRunning := True;

  // Initialize SDL3 with video and audio
  if not SDL_Init(SDL_INIT_VIDEO or SDL_INIT_AUDIO) then
  begin
    WriteLn('Failed to init SDL: ', SDL_GetError());
    Exit;
  end;

  // Initialize SDL3_Mixer
  if not MIX_Init() then
  begin
    WriteLn('Failed to init SDL3_Mixer: ', SDL_GetError());
    SDL_Quit();
    Exit;
  end;

  // Create window
  LWindow := SDL_CreateWindow(CWindowTitle, CScreenWidth, CScreenHeight, 0);
  if LWindow = nil then
  begin
    WriteLn('Failed to create window: ', SDL_GetError());
    MIX_Quit();
    SDL_Quit();
    Exit;
  end;

  // Create renderer
  LRenderer := SDL_CreateRenderer(LWindow, nil);
  if LRenderer = nil then
  begin
    WriteLn('Failed to create renderer: ', SDL_GetError());
    SDL_DestroyWindow(LWindow);
    MIX_Quit();
    SDL_Quit();
    Exit;
  end;

  // Create mixer device (uses default playback device)
  LMixer := MIX_CreateMixerDevice(SDL_AUDIO_DEVICE_DEFAULT_PLAYBACK, nil);
  if LMixer = nil then
  begin
    WriteLn('Failed to create mixer: ', SDL_GetError());
    SDL_DestroyRenderer(LRenderer);
    SDL_DestroyWindow(LWindow);
    MIX_Quit();
    SDL_Quit();
    Exit;
  end;

  // Load audio file
  LAudio := MIX_LoadAudio(LMixer, 'res/music/song01.ogg', True);
  if LAudio = nil then
  begin
    WriteLn('Failed to load audio: ', SDL_GetError());
    MIX_DestroyMixer(LMixer);
    SDL_DestroyRenderer(LRenderer);
    SDL_DestroyWindow(LWindow);
    MIX_Quit();
    SDL_Quit();
    Exit;
  end;

  // Create track
  LTrack := MIX_CreateTrack(LMixer);
  if LTrack = nil then
  begin
    WriteLn('Failed to create track: ', SDL_GetError());
    MIX_DestroyAudio(LAudio);
    MIX_DestroyMixer(LMixer);
    SDL_DestroyRenderer(LRenderer);
    SDL_DestroyWindow(LWindow);
    MIX_Quit();
    SDL_Quit();
    Exit;
  end;

  // Assign audio to track
  MIX_SetTrackAudio(LTrack, LAudio);

  // Create properties for looping (-1 = infinite loop)
  LProps := SDL_CreateProperties();
  SDL_SetNumberProperty(LProps, MIX_PROP_PLAY_LOOPS_NUMBER, -1);

  // Play track with looping
  MIX_PlayTrack(LTrack, LProps);

  // Clean up properties
  SDL_DestroyProperties(LProps);

  WriteLn('Playing song01.ogg (looping) - Press ESC or close window to exit');

  // Main loop
  while LRunning do
  begin
    // Handle events
    while SDL_PollEvent(@LEvent) do
    begin
      if LEvent.type_ = SDL_EVENT_QUIT then
        LRunning := False;
      if LEvent.type_ = SDL_EVENT_KEY_DOWN then
      begin
        if LEvent.key.key = SDLK_ESCAPE then
          LRunning := False;
      end;
    end;

    // Clear to dark blue
    SDL_SetRenderDrawColor(LRenderer, 20, 40, 80, 255);
    SDL_RenderClear(LRenderer);

    // Present
    SDL_RenderPresent(LRenderer);

    // Small delay to avoid burning CPU
    SDL_Delay(16);
  end;

  // Cleanup
  MIX_StopTrack(LTrack, 0);
  MIX_DestroyTrack(LTrack);
  MIX_DestroyAudio(LAudio);
  MIX_DestroyMixer(LMixer);
  SDL_DestroyRenderer(LRenderer);
  SDL_DestroyWindow(LWindow);
  MIX_Quit();
  SDL_Quit();
end;

procedure TestSDL3(const ANum: Integer);
begin
  case ANum of
    01: Test01();
    02: Test02();
    03: Test03();
  end;
end;

end.
