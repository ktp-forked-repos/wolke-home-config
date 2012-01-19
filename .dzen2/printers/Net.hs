module Net(main) where
import System.IO (stdout, hFlush)
import System.Process(readProcess, system)
import System.Posix.Process (forkProcess)
import System.Posix (sleep)
import System.Posix.IO (stdInput, stdOutput, stdError, closeFd)
import System.Environment (getEnv)
import Control.Applicative ((<$>))
import Control.Concurrent (threadDelay)
import Control.Monad (void, forever)
import Data.Maybe (listToMaybe)
import Text.Regex.PCRE
import TextRows (textRows)
import ClickAction (clickAction)

height = 36

cmd home = wscanCmd ++ " | " ++ popupCmd ++ dzenArgs
  where wscanCmd = home ++ "/.dzen2/printers/wscan"
        popupCmd = home ++ "/.dzen2/launchers/popup"
        dzenArgs = " 500 24 -fn inconsolata-14 "

data WStatus = Wlan | PPP | None | Unknown deriving(Eq)

readWStatus :: IO WStatus
readWStatus = do 
  wstatus <- readProcess "wstatus" [] ""
  case wstatus of
    "wlan\n"  -> return Wlan
    "ppp\n"   -> return PPP
    "none\n"  -> return None
    otherwise -> return Unknown


main = forever $ do
  wstatus <- readWStatus
  case wstatus of
    Wlan    -> wifi
    PPP     -> ppp
    None    -> none
    Unknown -> unknown
  hFlush stdout
  threadDelay $ 1 * 10^6

unknown = do
  home <- getEnv "HOME"
  putStrLn $ clickAction "1" (cmd home) "???"

none = do
  home <- getEnv "HOME"
  wauto <- readProcess "wauto" ["--get"] ""
  checkNone 4
  if wauto == "auto\n" then runAuto else putStr ""
  let top = "no wabs"
  let bot = chomp wauto
  putStrLn $ clickAction "1" (cmd home) (textRows top bot height)

checkNone 0 = return True
checkNone c = do
  sleep 1
  wstatus <- readWStatus
  if wstatus == None then checkNone (c-1) else return False

runAuto = void $ forkProcess $ do
  check <- checkNone 3
  if not check then return () else do
    mapM_ closeFd [stdInput, stdOutput, stdError]
    void $ system "wauto --connect"

ppp = do
  home <- getEnv "HOME"
  putStrLn $ clickAction "1" (cmd home) "pewpewpew"

wifi = do
  home <- getEnv "HOME"
  wlan <- chomp <$> readProcess "ifdev" ["wlan"] ""
  s <- readProcess "iwconfig" [wlan] ""
  let ssid = getMatch s "ESSID:\"(.*)\""
  let freq = getMatch s "Frequency:(\\d+(\\.\\d+)?) GHz"
  let qTop = getMatch s "Link Quality=(\\d+)/\\d+"
  let qBot = getMatch s "Link Quality=\\d+/(\\d+)"
  let rate = getMatch s "Bit Rate=(\\d+) Mb/s"
  let q = quality qTop qBot
  let f = frequency freq
  let top = (padtrim 3 rate ++ "m") ++ "|" ++ (quality qTop qBot)
  let bot = (padtrim 9 ssid)
  putStrLn $ clickAction "1" (cmd home) (textRows top bot height)

i = read :: String -> Integer
d = read :: String -> Double

padtrim len (Just s) = pad len $ take len $ s
padtrim len Nothing = take len $ repeat '?'

frequency (Just f) = show $ round $ (1000.0 * (d f))
frequency Nothing = "????"

quality (Just top) (Just bot) = pad 4 (per ++ "%")
  where per = show $ 100 * (i top) `div` (i bot)
quality _ _ = "???%"

pad len s | length s < len = pad len (' ':s)
pad _ s = s

--my $mbps = $1 if $iwconfig =~ /Bit Rate=(\d+) Mb\/s/;

getMatch s p = listToMaybe $ concat $ map tail groupSets
  where groupSets = s =~ p :: [[String]]

chomp "" = ""
chomp s | last s == '\n' = reverse $ tail $ reverse s
chomp s | otherwise = s
