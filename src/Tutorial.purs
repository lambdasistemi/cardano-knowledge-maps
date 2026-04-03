-- | Tutorial data types and decoder.
module Tutorial
  ( Tutorial
  , TutorialStop
  , decodeTutorial
  ) where

import Prelude

import Data.Argonaut.Core (Json)
import Data.Argonaut.Decode.Class (decodeJson)
import Data.Argonaut.Decode.Combinators ((.:))
import Data.Argonaut.Decode.Error (printJsonDecodeError)
import Data.Either (Either(..))
import Data.Traversable (traverse)

-- | A single stop in a tutorial.
type TutorialStop =
  { node :: String
  , depth :: Int
  , title :: String
  , narrative :: String
  }

-- | A complete tutorial with metadata and stops.
type Tutorial =
  { id :: String
  , title :: String
  , description :: String
  , stops :: Array TutorialStop
  }

-- | Decode a tutorial from JSON.
decodeTutorial :: Json -> Either String Tutorial
decodeTutorial json = do
  obj <- lmap' $ decodeJson json
  id <- lmap' $ obj .: "id"
  title <- lmap' $ obj .: "title"
  description <- lmap' $ obj .: "description"
  rawStops <- lmap' $ obj .: "stops"
  stops <- traverse decodeStop rawStops
  pure { id, title, description, stops }

decodeStop :: Json -> Either String TutorialStop
decodeStop json = do
  obj <- lmap' $ decodeJson json
  node <- lmap' $ obj .: "node"
  depth <- lmap' $ obj .: "depth"
  title <- lmap' $ obj .: "title"
  narrative <- lmap' $ obj .: "narrative"
  pure { node, depth, title, narrative }

lmap' :: forall a. Either _ a -> Either String a
lmap' (Left e) = Left (printJsonDecodeError e)
lmap' (Right a) = Right a
