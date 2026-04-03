-- | Thin FFI to Cytoscape.js. All graph logic lives
-- | in PureScript; this module only handles rendering.
module FFI.Cytoscape
  ( initCytoscape
  , setElements
  , setFocusElements
  , onNodeTap
  , onNodeHover
  , onEdgeHover
  , markRoot
  , clearRoot
  , fitAll
  ) where

import Prelude

import Effect (Effect)
import Foreign (Foreign)

-- | Create a Cytoscape.js instance with kind styles.
-- | First arg: container element ID.
-- | Second arg: kind definitions as Foreign
-- |   (object of { color, shape } keyed by kind ID).
foreign import initCytoscape
  :: String -> Foreign -> Effect Unit

-- | Replace all elements and re-run layout.
foreign import setElements
  :: Foreign -> Effect Unit

-- | Replace elements for focus mode.
-- | All edge labels visible.
foreign import setFocusElements
  :: Foreign -> Effect Unit

-- | Register a tap callback on nodes.
foreign import onNodeTap
  :: (String -> Effect Unit) -> Effect Unit

-- | Register a hover (mouseover) callback on nodes.
foreign import onNodeHover
  :: (String -> Effect Unit) -> Effect Unit

-- | Register a hover callback on edges.
foreign import onEdgeHover
  :: (String -> String -> String -> String -> Effect Unit)
  -> Effect Unit

-- | Mark a node as the focus root (white border).
foreign import markRoot :: String -> Effect Unit

-- | Clear root marking from all nodes.
foreign import clearRoot :: Effect Unit

-- | Fit the viewport to all elements.
foreign import fitAll :: Effect Unit
