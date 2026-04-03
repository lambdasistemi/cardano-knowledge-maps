-- | Full-text search across nodes and edges.
module Graph.Search
  ( SearchResult(..)
  , search
  ) where

import Prelude

import Data.Array as Array
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.String (Pattern(..), contains, toLower)
import Graph.Types (Edge, Graph, Node, NodeId)

-- | A search hit: either a node or an edge.
data SearchResult
  = NodeResult Node
  | EdgeResult
      { edge :: Edge
      , sourceLabel :: String
      , targetLabel :: String
      }

-- | Search nodes and edges by query string.
-- | Matches against labels, descriptions, and kind.
search :: String -> Graph -> Array SearchResult
search "" _ = []
search rawQuery graph =
  nodeResults <> edgeResults
  where
  q = toLower rawQuery

  allNodes = Array.fromFoldable
    (Map.values graph.nodes)

  nodeResults = Array.mapMaybe matchNode allNodes

  matchNode :: Node -> Maybe SearchResult
  matchNode node =
    if
      matchesAny
        [ node.label
        , node.description
        , node.kind
        ] then Just (NodeResult node)
    else Nothing

  edgeResults = Array.mapMaybe matchEdge graph.edges

  matchEdge :: Edge -> Maybe SearchResult
  matchEdge edge =
    let
      srcLabel = lookupLabel edge.source
      tgtLabel = lookupLabel edge.target
    in
      if
        matchesAny
          [ edge.label
          , edge.description
          , srcLabel
          , tgtLabel
          ] then Just
        ( EdgeResult
            { edge
            , sourceLabel: srcLabel
            , targetLabel: tgtLabel
            }
        )
      else Nothing

  lookupLabel :: NodeId -> String
  lookupLabel nid = case Map.lookup nid graph.nodes of
    Just n -> n.label
    Nothing -> nid

  matchesAny :: Array String -> Boolean
  matchesAny = Array.any
    (\s -> contains (Pattern q) (toLower s))
