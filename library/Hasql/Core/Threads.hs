module Hasql.Core.Threads where

import Hasql.Prelude
import Hasql.Core.Model
import qualified Hasql.Socket as A
import qualified Data.ByteString as B


{-|
Fork off a thread, which will be fetching chunks of data from the socket, feeding them to the handler action.
-}
startReceiving :: A.Socket -> (ByteString -> IO ()) -> (Text -> IO ()) -> IO (IO ())
startReceiving socket sendResult reportError =
  fmap killThread $ forkIO $ fix $ \loop -> do
    resultOfReceiving <- A.receive socket (shiftL 2 12)
    case resultOfReceiving of
      Right bytes ->
        if B.null bytes
          then reportError "Connection interrupted"
          else sendResult bytes >> loop
      Left msg ->
        reportError msg

startSending :: A.Socket -> IO ByteString -> (Text -> IO ()) -> IO (IO ())
startSending socket getNextChunk reportError =
  fmap killThread $ forkIO $ fix $ \loop -> do
    bytes <- getNextChunk
    resultOfSending <- A.send socket bytes
    case resultOfSending of
      Right () -> loop
      Left msg -> reportError msg

startSlicing :: IO ByteString -> (Message -> IO ()) -> IO (IO ())
startSlicing getNextChunk sendMessage =
  fmap killThread $ forkIO $
  $(todo "")

startMaintainingConnection :: A.Socket -> IO (IO ())
startMaintainingConnection socket =
  do
    inputQueue <- newTQueueIO
    outputQueue <- newTQueueIO
    messageQueue <- newTQueueIO
    errorVar <- newEmptyTMVarIO
    stopSending <- startSending socket (atomically (readTQueue outputQueue)) (atomically . putTMVar errorVar . TransportError)
    stopReceiving <- startReceiving socket (atomically . writeTQueue inputQueue) (atomically . putTMVar errorVar . TransportError)
    stopSlicing <- startSlicing (atomically (readTQueue inputQueue)) (atomically . writeTQueue messageQueue)
    let
      stopMaintaining = stopSlicing >> stopReceiving >> stopSending
      in return (stopMaintaining)
