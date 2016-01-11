import qualified Widgets as W
import Color (Color(..), hexColor)
import WMLog (WMLogConfig(..))
import Utils (colW)
import Width (charsFitInPx, getScreenDPI, screenPctToPx)

import Graphics.UI.Gtk.General.RcStyle (rcParseString)
import System.Taffybar (defaultTaffybar, defaultTaffybarConfig,
  barHeight, barPosition, widgetSpacing, startWidgets, endWidgets,
  Position(Top, Bottom))

import Data.Functor ((<$>))
import System.Environment (getArgs)

profile = profileFHD

profileFHD = P { height = 38
               , spacing = 5
               , titleLen = 30
               , typeface = "Inconsolata medium"
               , fontSizePt = 13.0
               , graphWidth = 50
               , workspaceImageHeight = 24
               }
profileHDPlus = P { height = 38
                  , spacing = 4
                  , titleLen = 30
                  , typeface = "Inconsolata medium"
                  , fontSizePt = 12.0
                  , graphWidth = 30
                  , workspaceImageHeight = 16
                  }

main = do
  dpi <- getScreenDPI
  isBot <- elem "--bottom" <$> getArgs
  klompWidthPx <- screenPctToPx 19.4271
  let cfg = defaultTaffybarConfig { barHeight=height profile
                                  , widgetSpacing= spacing profile
                                  , barPosition=if isBot then Bottom else Top
                                  }

      font = (typeface profile) ++ " " ++ show (fontSizePt profile)
      fgColor = hexColor $ RGB (0x93/0xff, 0xa1/0xff, 0xa1/0xff)
      bgColor = hexColor $ RGB (0x00/0xff, 0x2b/0xff, 0x36/0xff)
      textColor = hexColor $ Black
      sep = W.sepW Black 3
      klompChars = charsFitInPx dpi (fontSizePt profile) klompWidthPx

      start = [ W.wmLogNew WMLogConfig
                { titleLength = titleLen profile
                , wsImageHeight = workspaceImageHeight profile
                , titleRows = True
                , stackWsTitle = False
                , wsBorderColor = RGB (0.6, 0.5, 0.2)
                }
              ]
      end = reverse
          [ W.monitorCpuW $ graphWidth profile
          , W.monitorMemW $ graphWidth profile
          , W.progressBarW
          , W.netStatsW
          , sep
          , W.netW
          , sep
          , (W.widthCharWrapW dpi (fontSizePt profile) klompChars) =<< W.klompW klompChars
          , sep
          , W.speakerW
          , W.volumeW
          , W.micW
          , W.cpuIntelPstateW
          , W.cpuFreqsW
          , W.brightnessW
          , W.screenSaverW
          , colW [ W.pingMonitorW "G" "www.google.com"
                 ]
          , sep
          , W.clockW
          ]

  rcParseString $ ""
        ++ "style \"default\" {"
        ++ "  font_name = \"" ++ font ++ "\""
        ++ "  bg[NORMAL] = \"" ++ bgColor ++ "\""
        ++ "  fg[NORMAL] = \"" ++ fgColor ++ "\""
        ++ "  text[NORMAL] = \"" ++ textColor ++ "\""
        ++ "}"
  defaultTaffybar cfg {startWidgets=start, endWidgets=end}

data Profile = P { height :: Int
                 , spacing :: Int
                 , titleLen :: Int
                 , typeface :: String
                 , fontSizePt :: Double
                 , graphWidth :: Int
                 , workspaceImageHeight :: Int
                 }
