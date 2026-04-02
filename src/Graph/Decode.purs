-- | Decode the graph.json data file.
module Graph.Decode
  ( decodeGraph
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
import Data.Maybe (fromMaybe)
import Data.Traversable (traverse)
import Graph.Build (buildGraph)
import Graph.Types (Edge, Graph, Link, Node, NodeKind)

-- | Decode a JSON value into a Graph.
decodeGraph :: Json -> Either String Graph
decodeGraph json = do
  obj <- lmap' $ decodeJson json
  rawNodes <- lmap' $ obj .: "nodes"
  rawEdges <- lmap' $ obj .: "edges"
  nodes <- traverse decodeNode rawNodes
  edges <- traverse decodeEdge rawEdges
  pure $ buildGraph nodes edges

decodeNode :: Json -> Either String Node
decodeNode json = do
  obj <- lmap' $ decodeJson json
  id <- lmap' $ obj .: "id"
  label <- lmap' $ obj .: "label"
  kind <- lmap' $ (obj .: "kind" :: Either JsonDecodeError NodeKind)
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
  pure { source, target, label }

lmap'
  :: forall a
   . Either JsonDecodeError a
  -> Either String a
lmap' (Left e) = Left (printJsonDecodeError e)
lmap' (Right a) = Right a
