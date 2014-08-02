{-# LANGUAGE TemplateHaskell #-}
import Bindings (
  workspaceNames, myKeyBindings, myMouseBindings, keyOverlaps, mouseOverlaps,
  tryWriteKeyBindingsCache)
import StaticAssert (staticAssert)

import XMonad (
  xmonad,
  (<+>), (=?), (-->),
  XConfig(..), defaultConfig, mod1Mask,
  Tall(..), Mirror(..), Full(..),
  ask, title, className, doF, doFloat, doIgnore, doShift,
  sendMessage, io, spawn, killWindow, liftX, refresh)
import XMonad.Hooks.EwmhDesktops (ewmh)
import XMonad.Hooks.ManageDocks (avoidStruts, SetStruts(..), manageDocks)
import XMonad.Layout.LayoutCombinators ((|||), JumpToLayout(..))
import XMonad.Layout.Named (named)
import XMonad.Layout.NoBorders (smartBorders)
import XMonad.StackSet (sink, view)
import XMonad.Util.Types (Direction2D(U,D,L,R))

import System.Taffybar.Hooks.PagerHints (pagerHints)

import Control.Concurrent (threadDelay)
import Control.Monad.Writer (execWriter, tell)
import System.Directory (getHomeDirectory)

staticAssert (null mouseOverlaps && null keyOverlaps) . execWriter $ do
    tell "Error: Overlap in bindings\n"
    let pretty = tell . unlines . map ((replicate 8 ' ' ++) . show . map fst)
    pretty mouseOverlaps
    pretty keyOverlaps

firefoxExec = "iceweasel"
firefoxProcess = "iceweasel"
firefoxClose = "Close Iceweasel"
thunderbirdClass = "Icedove"

relToHomeDir file = fmap (++ "/" ++ file) getHomeDirectory

main = xmonad . ewmh . pagerHints $ defaultConfig
  { focusFollowsMouse  = False
  , modMask            = mod1Mask
  , normalBorderColor  = "#dddddd"
  , focusedBorderColor = "#ff0000"
  , borderWidth        = 3

  , startupHook        = myStartupHook
  , layoutHook         = myLayoutHook
  , manageHook         = myManageHook <+> manageDocks

  , workspaces         = workspaceNames
  , keys               = myKeyBindings
  , mouseBindings      = myMouseBindings
  }

myStartupHook = do
  spawn "find $HOME/.xmonad/ -regex '.*\\.\\(hi\\|o\\)' -delete"
  io $ tryWriteKeyBindingsCache =<< relToHomeDir ".cache/xmonad-bindings"

myLayoutHook = avoidStruts . smartBorders
             $   named "left" (Tall 1 incr ratio)
             ||| named "top"  (Mirror $ Tall 1 incr ratio)
             ||| named "full" Full
  where incr = 3/100 ; ratio = 55/100

myManageHook = execWriter $ do
  let a ~~> b = tell (a --> b)
  title     =? "Find/Replace "         ~~> doFloat
  className =? "Eclipse"               ~~> (doShift "A" <+> doUnfloat)
  title     =? "GWT Development Mode"  ~~> doShift "G"
  className =? "Pidgin"                ~~> doShift "B"
  className =? thunderbirdClass        ~~> doShift "8"
  title     =? "Off"                   ~~> doFloat
  title     =? "Transmission"          ~~> doShift "9"
  className =? "Transmission-gtk"      ~~> doUnfloat
  title     =? "Torrent Options"       ~~> doShiftView "9"
  title     =? firefoxClose            ~~> restartFF
  title     =? "qtbigtext.py"          ~~> doFull
  title     =? "StepMania"             ~~> doFull
  title     =? "npviewer.bin"          ~~> doFull -- flash
  title     =? "plugin-container"      ~~> doFull -- flash
  title     =? "xfce4-notifyd"         ~~> doIgnore

restartFF = do
  w <- ask
  let delay = 1
  let msg = "'restarting " ++ firefoxExec ++ " in " ++ show delay ++ "s'"
  liftX $ do
    spawn $ "killall -9 " ++ firefoxProcess
    killWindow w
    spawn $ "notify-send -t 3000 " ++ msg
    io . threadDelay $ delay*10^6
    spawn firefoxExec
    refresh
  doF id

doFull = do
  liftX . sendMessage $ removeStruts
  liftX . sendMessage $ JumpToLayout "full"
  doF id

doUnfloat = ask >>= doF . sink

addStruts = SetStruts [U,D,L,R] []
removeStruts = SetStruts [] [U,D,L,R]

doView workspace = doF $ view workspace
doShiftView workspace = doShift workspace <+> doView workspace
