-- | Core types for the knowledge graph browser.
module Graph.Types
  ( NodeId
  , KindId
  , KindDef
  , Link
  , Node
  , Edge
  , Graph
  , Config
  , emptyGraph
  , emptyConfig
  ) where

import Prelude

import Data.Map (Map)
import Data.Map as Map
import Data.Set (Set)

-- | Unique identifier for a node.
type NodeId = String

-- | Kind identifier (e.g. "actor", "process").
type KindId = String

-- | Kind definition from config.
type KindDef =
  { label :: String
  , color :: String
  , shape :: String
  }

-- | An external link associated with a node.
type Link =
  { label :: String
  , url :: String
  }

-- | A node in the knowledge graph.
type Node =
  { id :: NodeId
  , label :: String
  , kind :: KindId
  , group :: String
  , description :: String
  , links :: Array Link
  }

-- | A directed edge in the knowledge graph.
type Edge =
  { source :: NodeId
  , target :: NodeId
  , label :: String
  , description :: String
  }

-- | The full graph: nodes, edges, and adjacency.
type Graph =
  { nodes :: Map NodeId Node
  , edges :: Array Edge
  , forward :: Map NodeId (Set NodeId)
  , backward :: Map NodeId (Set NodeId)
  }

-- | Application configuration loaded from config.json.
type Config =
  { title :: String
  , description :: String
  , sourceUrl :: String
  , kinds :: Map KindId KindDef
  }

-- | An empty graph.
emptyGraph :: Graph
emptyGraph =
  { nodes: Map.empty
  , edges: []
  , forward: Map.empty
  , backward: Map.empty
  }

-- | Default empty config.
emptyConfig :: Config
emptyConfig =
  { title: "Knowledge Graph"
  , description: ""
  , sourceUrl: ""
  , kinds: Map.empty
  }
