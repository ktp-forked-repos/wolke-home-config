module Utils(
  defaultDelay, getHome, getHomeFile, imageDir,
  maybeJoin,
  fg, bg, fgbg,
  rowW, colW, containerW, widgetSetClass,
  regexMatch, regexAllMatches, regexAllSubmatches, regexGroups, regexFirstGroup,
  readInt, readDouble, printfReal, collectInts,
  stringWidth, trimL, trimR, padL, padR, padCols, uncols, chompAll,
  pollingGraphMain,
  ifM,
  tryMaybe, millisTime, nanoTime, isRunning, chompFile, findName,
  isSymlink, attemptCreateSymlink,
  systemReadLines, readProc, chompProc, procSuccess,
  procToChan, actToChanDelay, listToChan
) where
import Control.Concurrent (
  forkIO, threadDelay,
  Chan, writeChan, writeList2Chan, newChan)
import Control.Exception (catch, throwIO, SomeException, try)
import Control.Monad (forever, join, void)
import Data.Char (chr)
import Data.List (partition)
import qualified Data.Set as Set
import Graphics.UI.Gtk (
  Container, Widget, WidgetClass, hBoxNew, vBoxNew, containerAdd,
  toWidget, toContainer, widgetShowAll, widgetGetStyleContext)
import Graphics.UI.Gtk.General.StyleContext (styleContextAddClass)
import System.Exit(ExitCode(ExitFailure), ExitCode(ExitSuccess))
import System.Directory (doesFileExist, doesDirectoryExist, removeFile)
import Text.Regex.PCRE ((=~), getAllTextMatches, AllTextMatches)
import Data.Maybe (catMaybes, fromMaybe, listToMaybe)
import Data.List (intercalate, transpose)
import System.Environment (getEnv)
import System.FilePath.Find (
  (||?), (&&?), (==?), (~~?), (/=?),
  find, filePath, fileName, depth)
import System.IO (
  stderr, hGetContents, hGetLine, hPutStrLn,
  hSetBuffering, BufferMode(LineBuffering))
import System.IO.Error (isDoesNotExistError)
import System.Process (
  StdStream(CreatePipe), std_out, createProcess, proc, shell,
  system)
import ProcUtil ( readProcessWithExitCode' )
import System.Posix.Files (
  getSymbolicLinkStatus, isSymbolicLink, createSymbolicLink)
import System.Posix.Clock (timeSpecToInt64, monotonicClock, getClockTime)
import Text.Printf (printf)

-- CONSTANTS
defaultDelay :: Double
defaultDelay = 1

getHome = getEnv "HOME"
getHomeFile file = fmap (++ "/" ++ file) getHome

imageDir h = getHomeFile $ ".config/taffybar/icons/" ++ show h

-- FUNCTIONS
maybeJoin :: (a -> Maybe b) -> Maybe a -> Maybe b
maybeJoin f m = join $ fmap f m

-- MARKUP
fg color m = "<span foreground=\"" ++ color ++ "\">" ++ m ++ "</span>"
bg color m = "<span background=\"" ++ color ++ "\">" ++ m ++ "</span>"
fgbg fg bg m = "<span"
               ++ " foreground=\"" ++ fg ++ "\""
               ++ " background=\"" ++ bg ++ "\""
               ++ ">" ++ m ++ "</span>"

-- WIDGETS
rowW :: [IO Widget] -> IO Widget
rowW widgets = containerW widgets =<< toContainer `fmap` hBoxNew False 0

colW :: [IO Widget] -> IO Widget
colW widgets = containerW widgets =<< toContainer `fmap` vBoxNew False 0

containerW :: [IO Widget] -> Container -> IO Widget
containerW widgets box = do
  ws <- sequence widgets
  mapM_ (containerAdd box) ws
  widgetShowAll box
  return $ toWidget box

widgetSetClass :: WidgetClass w => w -> String -> IO ()
widgetSetClass widget klass = do
  context <- widgetGetStyleContext widget
  styleContextAddClass context klass

-- PARSING
regexMatch :: String -> String -> Bool
regexMatch = flip (=~)
regexGroups :: String -> String -> Maybe [String]
regexGroups re str = fmap (drop 1) $ listToMaybe $ str =~ re
regexFirstGroup :: String -> String -> Maybe String
regexFirstGroup re str = listToMaybe $ fromMaybe [] $ regexGroups re str
regexAllMatches :: String -> String -> [String]
regexAllMatches re str = getAllTextMatches $ (str =~ re :: AllTextMatches [] String)
regexAllSubmatches :: String -> String -> [[String]]
regexAllSubmatches re str = str =~ re

readInt :: String -> Maybe Integer
readInt s = case reads s of
              ((x,_):_) -> Just x
              _ -> Nothing

readDouble :: String -> Maybe Double
readDouble s = case reads s of
              ((x,_):_) -> Just x
              _ -> Nothing

printfReal :: Real a => String -> a -> String
printfReal fmt rat = printf fmt $ (fromRational $ toRational rat :: Double)

collectInts :: String -> [Integer]
collectInts = catMaybes . (map readInt) . (regexAllMatches "\\d+")

stringWidth :: String -> Int
stringWidth s = hwcs*1 + fwcs*2
  where fwcs = length $ filter isFullWidthChar s
        hwcs = length s - fwcs --partition is much slower

isFullWidthChar :: Char -> Bool
isFullWidthChar ch = Set.member ch fullwidthCharSet

fullwidthCharSet :: Set.Set Char
fullwidthCharSet = Set.fromList $ map chr $ []
  ++ [0x30A0  .. 0x30FF ] --katakana
  ++ [0x1100  .. 0x11FF ] --hangul
  ++ [0xFF01  .. 0xFF60 ] --roman fullwidth
  ++ [0x4E00  .. 0x9FFF ] --han common
  ++ [0x3400  .. 0x4DBF ] --han rare
  ++ [0x20000 .. 0x2A6DF] --han rare historic
  ++ [0x2A700 .. 0x2B73F] --han rare historic
  ++ [0x2B820 .. 0x2CEAF] --han rare historic
  ++ [0xF900  .. 0xFAFF ] --han duplicates, unifiable variants, corporate chars
  ++ [0x2F800 .. 0x2FA1F] --han unifiable variants

--remove chars from the left until stringWidth of str is <= len
trimL :: Int -> String -> String
trimL len str = trimLCh fwcs suffix
  where suffix = drop (length str - len) str
        fwcs = length $ filter isFullWidthChar suffix
        trimLCh _ [] = ""
        trimLCh chrs (x:xs) | chrs <= 0         = x:xs
                            | isFullWidthChar x = trimLCh (chrs-2) xs
                            | otherwise         = trimLCh (chrs-1) xs
--remove chars from the right until stringWidth of str is <= len
trimR len = reverse . trimL len . reverse

padL x len xs = replicate (len - stringWidth xs) x ++ xs
padR x len xs = xs ++ replicate (len - stringWidth xs) x

padCols :: [Either Char Char] -> [[String]] -> [[String]]
padCols format cols = map (pad widths format) cols where
  widths = map (maximum . map length) $ transpose cols

  pad []     []           []         = []
  pad []     fmts         cols       = pad [0] fmts       cols
  pad ws     []           cols       = pad ws  [Left ' '] cols
  pad ws     fmts         []         = pad ws  fmts       [""]
  pad [_]    [Left ' ']   [col]      = [col]
  pad (w:ws) (fmt:fmts)   (col:cols) = either (flip padL w) (flip padR w) fmt col
                                     : pad ws fmts cols

uncols :: String -> [Either Char Char] -> [[String]] -> String
uncols sep format = unlines . map (intercalate sep) . padCols format

chompAll = reverse . dropWhile (== '\n') . reverse

-- IO
pollingGraphMain delay reader = forever $ do
  values <- reader
  print $ map (printfReal "%.3f") values
  threadDelay $ round $ delay * 10^6

ifM :: Monad m => m Bool -> m a -> m a -> m a
ifM mTest mThen mElse = mTest >>= \test -> if test then mThen else mElse

tryMaybe :: (IO a) -> IO (Maybe a)
tryMaybe act = do
  result <- (try :: IO a -> IO (Either SomeException a)) act
  case result of
    Left ex  -> do
      hPutStrLn stderr $ show ex
      return Nothing
    Right val -> return $ Just val

millisTime :: IO Integer
millisTime = fmap (`div`10^6) nanoTime

nanoTime :: IO Integer
nanoTime = fmap (fromIntegral . timeSpecToInt64) $ getClockTime monotonicClock

isRunning :: String -> IO Bool
isRunning p = do
  running <- system $ "pgrep " ++ p ++ " > /dev/null 2>/dev/null"
  return $ case running of
    ExitFailure _ -> False
    otherwise -> True

--rough equivalent to:
--  recurse: find DIR -name PTRN
--  not recurse: find DIR -maxdepth 1 -name PTRN
findName :: FilePath -> Bool -> String -> IO [FilePath]
findName dir recurse ptrn = find rec match dir
  where rec = return recurse ||? depth ==? 0
        match = fileName ~~? ptrn &&? filePath /=? dir

--return True for symlink (broken or not broken)
isSymlink :: FilePath -> IO Bool
isSymlink filepath = (getIsSymlink filepath) `catch` (whenDNE (return False))
  where getIsSymlink = (fmap isSymbolicLink) . getSymbolicLinkStatus
        whenDNE a e = if isDoesNotExistError e then a else throwIO e

--if file does not exist, create new symlink
--if file exists and is a symlink, remove it and create a new symlink
--if file exists and is not a symlink, do nothing
attemptCreateSymlink :: FilePath -> String -> IO ()
attemptCreateSymlink f target = ifM isSym (rmFile >> createSym) (unlessM exists createSym)
  where isSym = isSymlink f
        exists = ifM (doesFileExist f) (return True) (doesDirectoryExist f)
        rmFile = removeFile f
        createSym = createSymbolicLink target f
        unlessM p a = ifM p (pure ()) a

chompFile :: FilePath -> IO String
chompFile file = do
  curExists <- doesFileExist file
  if curExists then fmap chompAll $ readFile file else return ""

systemReadLines :: String -> IO [String]
systemReadLines cmd = fmap lines $ sys >>= \(_,Just h,_,_) -> lineBufContent h
  where sys = createProcess (shell cmd) {std_out = CreatePipe}
        lineBufContent h = hSetBuffering h LineBuffering >> hGetContents h

readProc (cmd:args) = fmap snd3 $ readProcessWithExitCode' cmd args ""
  where snd3 (_,x,_) = x

chompProc = fmap chompAll . readProc

procSuccess (cmd:args) = do
  (exitCode,_,_) <- readProcessWithExitCode' cmd args ""
  return $ exitCode == ExitSuccess

procToHandle (cmd:args) = do
  (_,Just out,_,_) <- createProcess (proc cmd args) {std_out=CreatePipe}
  return out

procToChan cmdarr = do
  out <- procToHandle cmdarr
  hSetBuffering out LineBuffering
  chan <- newChan
  forkIO . forever $ writeChan chan =<< hGetLine out
  return chan

actToChanDelay :: Int -> IO a -> IO (Chan a)
actToChanDelay delayMicro act = do
  chan <- newChan
  forkIO $ forever $ do
    start <- nanoTime
    act >>= writeChan chan
    end <- nanoTime
    let elapsedMicro = (fromIntegral $ end - start) `div` 10^3
    threadDelay $ delayMicro - elapsedMicro
  return chan

listToChan :: [a] -> IO (Chan a)
listToChan xs = newChan >>= (\c -> forkIO (writeList2Chan c xs) >> return c)
