-- | Decode graph.json and config.json.
module Graph.Decode
  ( decodeGraph
  , decodeConfig
  ) where

import Prelude

import Data.Argonaut.Core (Json)
import Data.Argonaut.Decode.Class (decodeJson)
import Data.Argonaut.Decode.Combinators ((.:), (.:?))
import Data.Argonaut.Decode.Error
  ( JsonDecodeError
  , printJsonDecodeError
  )
import Data.Either (Either(..))
import Data.Map as Map
import Data.Maybe (fromMaybe)
import Data.Traversable (traverse)
import Data.Tuple (Tuple(..))
import Foreign.Object as FO
import Graph.Build (buildGraph)
import Graph.Types (Config, Edge, Graph, KindDef, Link, Node)

-- | Decode a JSON value into a Graph.
decodeGraph :: Json -> Either String Graph
decodeGraph json = do
  obj <- lmap' $ decodeJson json
  rawNodes <- lmap' $ obj .: "nodes"
  rawEdges <- lmap' $ obj .: "edges"
  nodes <- traverse decodeNode rawNodes
  edges <- traverse decodeEdge rawEdges
  pure $ buildGraph nodes edges

-- | Decode a JSON value into a Config.
decodeConfig :: Json -> Either String Config
decodeConfig json = do
  obj <- lmap' $ decodeJson json
  title <- lmap' $ obj .: "title"
  description <- lmap' $ obj .: "description"
  sourceUrl <- lmap' $ obj .: "sourceUrl"
  kindsObj <- lmap' $
    (obj .: "kinds" :: Either JsonDecodeError (FO.Object Json))
  kindPairs <- traverse
    ( \(Tuple k v) -> do
        def <- decodeKindDef v
        pure (Tuple k def)
    )
    (FO.toUnfoldable kindsObj :: Array _)
  pure
    { title
    , description
    , sourceUrl
    , kinds: Map.fromFoldable kindPairs
    }

decodeKindDef :: Json -> Either String KindDef
decodeKindDef json = do
  obj <- lmap' $ decodeJson json
  label <- lmap' $ obj .: "label"
  color <- lmap' $ obj .: "color"
  shape <- lmap' $ obj .: "shape"
  pure { label, color, shape }

decodeNode :: Json -> Either String Node
decodeNode json = do
  obj <- lmap' $ decodeJson json
  id <- lmap' $ obj .: "id"
  label <- lmap' $ obj .: "label"
  kind <- lmap' $ obj .: "kind"
  group <- lmap' $ obj .: "group"
  description <- lmap' $ obj .: "description"
  rawLinks <- lmap' $ fromMaybe [] <$> obj .:? "links"
  links <- traverse decodeLink rawLinks
  pure { id, label, kind, group, description, links }

decodeLink :: Json -> Either String Link
decodeLink json = do
  obj <- lmap' $ decodeJson json
  label <- lmap' $ obj .: "label"
  url <- lmap' $ obj .: "url"
  pure { label, url }

decodeEdge :: Json -> Either String Edge
decodeEdge json = do
  obj <- lmap' $ decodeJson json
  source <- lmap' $ obj .: "source"
  target <- lmap' $ obj .: "target"
  label <- lmap' $ obj .: "label"
  description <- lmap' $
    fromMaybe "" <$> obj .:? "description"
  pure { source, target, label, description }

lmap'
  :: forall a
   . Either JsonDecodeError a
  -> Either String a
lmap' (Left e) = Left (printJsonDecodeError e)
lmap' (Right a) = Right a
