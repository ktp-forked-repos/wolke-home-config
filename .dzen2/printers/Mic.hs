import System.Environment (getEnv)
import System.Process(readProcess)
import CommandClick (imgDir)
import ClickAction (clickAction)
import ClickableImage (clickableImage)

height = 36

main = do
 home <- getEnv "HOME"
 mic <- readProcess (home ++ "/bin/pulse-mute") ["microphone"] ""
 putStr $ formatCircle home (isMuted $ lines mic !! 0)

formatImg home isM = clickableImage [clickCmd] $ imgDir home ++ img
  where img | isM     = "microphone-muted.xpm"
            | not isM = "microphone-unmuted.xpm"

formatCircle home isM = clickAction "1" clickCmd markup
  where markup = color $ "^p(;" ++ (show shift) ++ ")^c(" ++ (show d) ++ ")"
        d = height `div` 6
        shift = height `div` 2 - d `div` 2
        color m = "^fg(" ++ fg ++ ")" ++ m ++ "^fg()"
        fg = if isM then "red" else "green"

isMuted mic | mic == "source is muted" = True
            | mic == "source is not muted" = False
            | otherwise = error ("unknown microphone status: " ++ mic)

clickCmd = "pulse-mute microphone toggle"
