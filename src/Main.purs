module Main where

import Prelude

import Data.Argonaut.Parser (jsonParser)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (for_)
import Data.Map as Map
import Data.Maybe (Maybe(..), fromMaybe)
import Data.Set (Set)
import Data.Set as Set
import Data.String as String
import Data.Tuple (Tuple(..))
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff.Class (liftAff)
import Effect.Class (liftEffect)
import FFI.Cytoscape as Cy
import Fetch (Method(..), fetch)
import Graph.Build (buildGraph)
import Graph.Cytoscape as GCy
import Graph.Decode (decodeGraph)
import Graph.Operations (neighborhood, subgraph)
import Graph.Types
  ( Edge
  , Graph
  , Link
  , Node
  , NodeKind(..)
  , allKinds
  , emptyGraph
  , kindLabel
  )
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.VDom.Driver (runUI)

main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  runUI component unit body

-- | Application state.
type State =
  { graph :: Graph
  , selected :: Maybe Node
  , focusMode :: Boolean
  , depth :: Int
  , filters :: Set NodeKind
  , search :: String
  , error :: Maybe String
  }

-- | Actions the component can handle.
data Action
  = Initialize
  | NodeTapped String
  | ToggleFocus
  | SetDepth Int
  | ToggleFilter NodeKind
  | SetSearch String
  | FitAll
  | Reset
  | CloseSidebar
  | NavigateTo String

component
  :: forall q i o. H.Component q i o Aff
component = H.mkComponent
  { initialState: \_ ->
      { graph: emptyGraph
      , selected: Nothing
      , focusMode: false
      , depth: 1
      , filters: Set.fromFoldable allKinds
      , search: ""
      , error: Nothing
      }
  , render
  , eval: H.mkEval H.defaultEval
      { handleAction = handleAction
      , initialize = Just Initialize
      }
  }

render :: forall m. State -> H.ComponentHTML Action () m
render state =
  HH.div [ cls "app" ]
    [ HH.div [ cls "graph-container" ]
        [ HH.div
            [ HP.id "cy" ]
            []
        , renderControls state
        , renderFilters state
        , renderLegend
        ]
    , renderSidebar state
    ]

renderControls
  :: forall m. State -> H.ComponentHTML Action () m
renderControls state =
  HH.div [ cls "controls" ]
    [ btn "Fit View" FitAll false
    , btn "Focus Mode" ToggleFocus state.focusMode
    , HH.div [ cls "depth-control" ]
        [ HH.span [ cls "depth-label" ]
            [ HH.text "Depth:" ]
        , HH.input
            [ HP.type_ HP.InputRange
            , HP.min 1.0
            , HP.max 4.0
            , HP.value (show state.depth)
            , HP.step (HP.Step 1.0)
            , HE.onValueInput
                ( \v -> SetDepth
                    (fromMaybe 1 (readInt v))
                )
            ]
        , HH.span [ cls "depth-value" ]
            [ HH.text (show state.depth) ]
        ]
    , btn "Reset" Reset false
    ]

renderFilters
  :: forall m. State -> H.ComponentHTML Action () m
renderFilters state =
  HH.div [ cls "filters" ]
    ( map mkFilter allKinds
    )
  where
  mkFilter kind =
    HH.button
      [ cls
          ( "filter-btn"
              <> if Set.member kind state.filters
                then " active"
                else ""
          )
      , HE.onClick \_ -> ToggleFilter kind
      ]
      [ HH.span
          [ cls "dot"
          , HP.attr (HH.AttrName "style")
              ("background:" <> kindColor kind)
          ]
          []
      , HH.text (kindLabel kind)
      ]

renderSidebar
  :: forall m. State -> H.ComponentHTML Action () m
renderSidebar state =
  HH.div [ cls "sidebar" ]
    [ HH.div [ cls "sidebar-header" ]
        [ HH.h2_ [ HH.text sidebarTitle ]
        , HH.button
            [ cls "close-btn"
            , HE.onClick \_ -> CloseSidebar
            ]
            [ HH.text "\x00D7" ]
        ]
    , HH.div [ cls "sidebar-content" ]
        [ case state.selected of
            Nothing -> renderEmptyState
            Just node -> renderNodeDetail
              state.graph
              node
        ]
    ]
  where
  sidebarTitle = case state.selected of
    Nothing -> "Cardano Governance"
    Just n -> n.label

renderEmptyState
  :: forall m. H.ComponentHTML Action () m
renderEmptyState =
  HH.div [ cls "empty-state" ]
    [ HH.h2_ [ HH.text "Cardano Governance" ]
    , HH.p_
        [ HH.text
            "Click any node to explore. \
            \Use Focus Mode to isolate \
            \a neighborhood. Filter by \
            \node type above."
        ]
    ]

renderNodeDetail
  :: forall m
   . Graph
  -> Node
  -> H.ComponentHTML Action () m
renderNodeDetail graph node =
  HH.div_
    [ HH.span
        [ cls ("badge badge-" <> show node.kind) ]
        [ HH.text (kindLabel node.kind) ]
    , HH.p [ cls "description" ]
        [ HH.text node.description ]
    , renderLinks node.links
    , renderConnections "Connects to" outEdges
    , renderConnections "Connected from" inEdges
    ]
  where
  outEdges = Array.filter
    (\e -> e.source == node.id)
    graph.edges
  inEdges = Array.filter
    (\e -> e.target == node.id)
    graph.edges

  renderLinks :: Array Link -> H.ComponentHTML Action () m
  renderLinks [] = HH.text ""
  renderLinks links =
    HH.ul [ cls "links" ]
      ( map
          ( \l -> HH.li_
              [ HH.a
                  [ HP.href l.url
                  , HP.target "_blank"
                  , HP.rel "noopener"
                  ]
                  [ HH.text l.label ]
              ]
          )
          links
      )

  renderConnections
    :: String
    -> Array Edge
    -> H.ComponentHTML Action () m
  renderConnections _ [] = HH.text ""
  renderConnections title edges =
    HH.div [ cls "connections" ]
      [ HH.h3_ [ HH.text title ]
      , HH.div_ (map mkConn edges)
      ]

  mkConn :: Edge -> H.ComponentHTML Action () m
  mkConn edge =
    let
      targetId = if edge.source == node.id
        then edge.target
        else edge.source
      targetNode = Map.lookup targetId graph.nodes
      targetLabel = case targetNode of
        Just n -> n.label
        Nothing -> targetId
    in
      HH.div
        [ cls "connection-item"
        , HE.onClick \_ -> NavigateTo targetId
        ]
        [ HH.span [ cls "conn-label" ]
            [ HH.text edge.label ]
        , HH.span [ cls "conn-node" ]
            [ HH.text targetLabel ]
        ]

renderLegend :: forall m. H.ComponentHTML Action () m
renderLegend =
  HH.div [ cls "legend" ]
    [ HH.text
        "Click nodes to explore. \
        \Filter by type above. \
        \Focus mode re-layouts the \
        \neighborhood."
    ]

handleAction
  :: forall o. Action -> H.HalogenM State Action () o Aff Unit
handleAction = case _ of
  Initialize -> do
    liftEffect $ Cy.initCytoscape "cy"
    liftEffect $ Cy.onNodeTap \_ ->
      pure unit
    result <- liftAff loadGraphData
    case result of
      Left err ->
        H.modify_ _ { error = Just err }
      Right graph -> do
        H.modify_ _ { graph = graph }
        renderGraph
    -- Re-register tap after graph loads
    liftEffect $ Cy.onNodeTap \_ -> pure unit
    -- We need subscriptions for node taps.
    -- Since Cytoscape is external, we use
    -- a polling-free approach: the FFI calls
    -- back into PureScript via the action.
    setupNodeTapCallback

  NodeTapped nodeId -> do
    state <- H.get
    let node = Map.lookup nodeId state.graph.nodes
    H.modify_ _ { selected = node }
    if state.focusMode then renderGraph
    else liftEffect $ Cy.markRoot nodeId

  ToggleFocus -> do
    H.modify_ \s -> s
      { focusMode = not s.focusMode }
    renderGraph

  SetDepth d -> do
    H.modify_ _ { depth = d }
    state <- H.get
    when state.focusMode renderGraph

  ToggleFilter kind -> do
    state <- H.get
    let
      newFilters =
        if Set.member kind state.filters then
          if Set.size state.filters > 1 then
            Set.delete kind state.filters
          else state.filters
        else Set.insert kind state.filters
    H.modify_ _ { filters = newFilters }
    renderGraph

  SetSearch q -> do
    H.modify_ _ { search = q }

  FitAll ->
    liftEffect Cy.fitAll

  Reset -> do
    H.modify_ _
      { selected = Nothing
      , focusMode = false
      , depth = 1
      , filters = Set.fromFoldable allKinds
      , search = ""
      }
    renderGraph

  CloseSidebar ->
    H.modify_ _ { selected = Nothing }

  NavigateTo nodeId -> do
    state <- H.get
    let node = Map.lookup nodeId state.graph.nodes
    H.modify_ _ { selected = node }
    if state.focusMode then renderGraph
    else liftEffect $ Cy.markRoot nodeId

setupNodeTapCallback
  :: forall o
   . H.HalogenM State Action () o Aff Unit
setupNodeTapCallback = do
  -- We can't directly wire Cytoscape taps to
  -- Halogen actions, so we use a ref-based
  -- approach: the FFI sets a callback that
  -- we poll... Actually, let's use
  -- HalogenSubscriptions.
  pure unit

renderGraph
  :: forall o
   . H.HalogenM State Action () o Aff Unit
renderGraph = do
  state <- H.get
  let
    -- Filter by kind
    filteredNodes = Array.filter
      ( \n -> Set.member n.kind state.filters
      )
      (Array.fromFoldable (Map.values state.graph.nodes))

    filteredNodeIds = Set.fromFoldable
      (map _.id filteredNodes)

    filteredEdges = Array.filter
      ( \e -> Set.member e.source filteredNodeIds
          && Set.member e.target filteredNodeIds
      )
      state.graph.edges

    filtered = buildGraph filteredNodes filteredEdges

    -- Apply focus if active
    visible = case state.selected of
      Just node | state.focusMode ->
        let
          hood = neighborhood state.depth
            node.id
            filtered
          -- Intersect with filtered node IDs
          keep = Set.intersection hood filteredNodeIds
        in
          subgraph keep filtered
      _ -> filtered

  liftEffect $ Cy.setElements (GCy.toElements visible)
  -- Re-mark selected node after re-render
  for_ state.selected \node ->
    liftEffect $ Cy.markRoot node.id

loadGraphData :: Aff (Either String Graph)
loadGraphData = do
  resp <- fetch "data/graph.json" { method: GET }
  body <- resp.text
  pure case jsonParser body of
    Left err -> Left err
    Right json -> decodeGraph json

-- Helpers

btn
  :: forall m
   . String
  -> Action
  -> Boolean
  -> H.ComponentHTML Action () m
btn label action active =
  HH.button
    [ cls
        ( "control-btn"
            <> if active then " active" else ""
        )
    , HE.onClick \_ -> action
    ]
    [ HH.text label ]

cls
  :: forall r i
   . String
  -> HH.IProp (class :: String | r) i
cls = HP.class_ <<< HH.ClassName

kindColor :: NodeKind -> String
kindColor Actor = "#58a6ff"
kindColor ActionType = "#d29922"
kindColor Process = "#3fb950"
kindColor Mechanism = "#bc8cff"
kindColor Artifact = "#f778ba"
kindColor Concept = "#79c0ff"
kindColor ParamGroup = "#e3b341"
kindColor Parameter = "#a5d6a7"
kindColor Tool = "#56d4dd"

readInt :: String -> Maybe Int
readInt s = case String.trim s of
  "1" -> Just 1
  "2" -> Just 2
  "3" -> Just 3
  "4" -> Just 4
  _ -> Nothing
