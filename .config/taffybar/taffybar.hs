import qualified Widgets as W
import Color (Color(..), hexColor)
import WMLog (WMLogConfig(..))
import Utils (colW, attemptCreateSymlink)
import Width (charsFitInPx, getScreenDPI, screenPctToPx)

import System.Taffybar (defaultTaffybar, defaultTaffybarConfig,
  barHeight, barPosition, widgetSpacing, startWidgets, endWidgets,
  Position(Top, Bottom))

import Data.Functor ((<$>))
import System.Environment (getArgs)
import System.Environment.XDG.BaseDir ( getUserConfigFile )

profile = profileFHDBig

--                rcSuf  barHt  wImgH  space  wSepW  title  fontP  graph  music
profileFHD    = P "fhd"     38     24      5      2     30   13.0     50  15.94
profileFHDBig = P "big"     42     28      5      3     30   16.0     50  19.43
profileHDPlus = P "hdp"     38     16      4      2     30   12.0     30  15.94

typeface = "Inconsolata medium"

data Profile = P { rcSuf :: String --suffix for autogenerated gtkrc file
                 , barHt :: Int    --bar height in pixels
                 , wImgH :: Int    --workspace image height in pixels
                 , space :: Int    --widget spacing in pixels
                 , wSepW :: Int    --widget separator width in pixels
                 , title :: Int    --window title length in characters
                 , fontP :: Double --font point size
                 , graph :: Int    --width of graphs in pixels
                 , music :: Double --percent of the screen width to use for song info
                 }

main = do
  dpi <- getScreenDPI
  isBot <- elem "--bottom" <$> getArgs
  klompWidthPx <- screenPctToPx $ music profile
  let cfg = defaultTaffybarConfig { barHeight = barHt profile
                                  , widgetSpacing = space profile
                                  , barPosition = if isBot then Bottom else Top
                                  }
      font = typeface ++ " " ++ show (fontP profile)
      fgColor = hexColor $ RGB (0x93/0xff, 0xa1/0xff, 0xa1/0xff)
      bgColor = hexColor $ RGB (0x00/0xff, 0x2b/0xff, 0x36/0xff)
      textColor = hexColor Black
      wsBorderColorNormal = hexColor $ RGB (0xD4/0xff, 0xAD/0xff, 0x35/0xff)
      wsBorderColorActive = hexColor Red
      sep = W.sepW Black $ wSepW profile
      klompChars = charsFitInPx dpi (fontP profile) klompWidthPx

      start = [ W.wmLogNew WMLogConfig
                { titleLength = title profile
                , wsImageHeight = wImgH profile
                , titleRows = True
                , stackWsTitle = False
                }
              ]
      end = reverse
          [ W.monitorCpuW $ graph profile
          , W.monitorMemW $ graph profile
          , W.progressBarW
          , W.netStatsW
          , sep
          , W.netW
          , sep
          , (W.widthCharWrapW dpi (fontP profile) klompChars) =<< W.klompW klompChars
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

  let rcNameMain = "taffybar.rc"
      rcNameProfile = rcNameMain  ++ "." ++ rcSuf profile

  rcFileMain <- getUserConfigFile "taffybar" rcNameMain
  rcFileProfile <- getUserConfigFile "taffybar" rcNameProfile

  writeFile rcFileProfile $ ""
        ++ "# profile: " ++ rcSuf profile ++ "\n"
        ++ "# auto-generated at: " ++ rcFileProfile ++ "\n"
        ++ "\n"
        ++ "style \"taffybar-default\" {\n"
        ++ "  font_name = \"" ++ font ++ "\"\n"
        ++ "  bg[NORMAL] = \"" ++ bgColor ++ "\"\n"
        ++ "  fg[NORMAL] = \"" ++ fgColor ++ "\"\n"
        ++ "  text[NORMAL] = \"" ++ textColor ++ "\"\n"
        ++ "}\n"
        ++ "style \"taffybar-workspace-border-active\" {\n"
        ++ "  bg[NORMAL] = \"" ++ wsBorderColorActive ++ "\"\n"
        ++ "}\n"
        ++ "style \"taffybar-workspace-border-visible\" {\n"
        ++ "  bg[NORMAL] = \"" ++ wsBorderColorActive ++ "\"\n"
        ++ "}\n"
        ++ "style \"taffybar-workspace-border-empty\" {\n"
        ++ "  bg[NORMAL] = \"" ++ wsBorderColorNormal ++ "\"\n"
        ++ "}\n"
        ++ "style \"taffybar-workspace-border-hidden\" {\n"
        ++ "  bg[NORMAL] = \"" ++ wsBorderColorNormal ++ "\"\n"
        ++ "}\n"
        ++ "style \"taffybar-workspace-border-urgent\" {\n"
        ++ "  bg[NORMAL] = \"" ++ wsBorderColorNormal ++ "\"\n"
        ++ "}\n"

  attemptCreateSymlink rcFileMain rcNameProfile

  defaultTaffybar cfg {startWidgets=start, endWidgets=end}
