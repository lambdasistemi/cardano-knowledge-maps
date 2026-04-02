module Main where

import Prelude

import Data.Argonaut.Parser (jsonParser)
import Data.Array as Array
import Data.Either (Either(..))
import Data.Foldable (foldl, for_)
import Data.Map as Map
import Data.Maybe (Maybe(..))
import Data.Set as Set
import Data.Tuple (Tuple(..), fst, snd)
import Effect (Effect)
import Effect.Aff (Aff)
import Effect.Aff.Class (liftAff)
import Effect.Class (liftEffect)
import FFI.Cytoscape as Cy
import Fetch (Method(..), fetch)
import Graph.Cytoscape as GCy
import Graph.Decode (decodeGraph)
import Graph.Operations (neighborhood, subgraph)
import Graph.Types
  ( Edge
  , Graph
  , Link
  , Node
  , NodeKind(..)
  , emptyGraph
  , kindLabel
  )
import Halogen as H
import Halogen.Aff as HA
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP
import Halogen.Subscription as HS
import Halogen.VDom.Driver (runUI)

main :: Effect Unit
main = HA.runHalogenAff do
  body <- HA.awaitBody
  runUI component unit body

-- | Application state.
type State =
  { graph :: Graph
  , selected :: Maybe Node
  , depth :: Int
  , error :: Maybe String
  }

-- | Actions the component can handle.
data Action
  = Initialize
  | NodeTapped String
  | NodeHovered String
  | SetDepth Int
  | FitAll
  | NavigateTo String

component
  :: forall q i o. H.Component q i o Aff
component = H.mkComponent
  { initialState: \_ ->
      { graph: emptyGraph
      , selected: Nothing
      , depth: 99
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
        [ HH.div [ HP.id "cy" ] []
        , renderControls state
        , renderLegend
        ]
    , renderSidebar state
    ]

renderControls
  :: forall m. State -> H.ComponentHTML Action () m
renderControls state =
  HH.div [ cls "controls" ]
    [ HH.button
        [ cls "control-btn"
        , HE.onClick \_ -> FitAll
        ]
        [ HH.text "Fit View" ]
    , HH.div [ cls "depth-control" ]
        [ HH.span [ cls "depth-label" ]
            [ HH.text "Depth:" ]
        , depthBtn 1 state.depth
        , depthBtn 2 state.depth
        , depthBtn 3 state.depth
        , HH.button
            [ cls
                ( "depth-btn"
                    <> if state.depth >= 99
                      then " active"
                      else ""
                )
            , HE.onClick \_ -> SetDepth 99
            ]
            [ HH.text "All" ]
        ]
    ]

renderSidebar
  :: forall m. State -> H.ComponentHTML Action () m
renderSidebar state =
  HH.div [ cls "sidebar" ]
    [ HH.div [ cls "sidebar-header" ]
        [ HH.h2_ [ HH.text sidebarTitle ]
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
    [ HH.h2_
        [ HH.text "Cardano Governance" ]
    , HH.p_
        [ HH.text
            "Hover a node to see details. \
            \Click to re-center. \
            \Use depth buttons to control \
            \neighborhood size."
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

  renderLinks
    :: Array Link -> H.ComponentHTML Action () m
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
      targetId =
        if edge.source == node.id then edge.target
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
        "Hover to inspect. Click to \
        \re-center. Depth controls \
        \neighborhood size."
    ]

handleAction
  :: forall o
   . Action
  -> H.HalogenM State Action () o Aff Unit
handleAction = case _ of
  Initialize -> do
    liftEffect $ Cy.initCytoscape "cy"
    tapSub <- liftEffect HS.create
    liftEffect $ Cy.onNodeTap \nodeId ->
      HS.notify tapSub.listener
        (NodeTapped nodeId)
    void $ H.subscribe tapSub.emitter
    hoverSub <- liftEffect HS.create
    liftEffect $ Cy.onNodeHover \nodeId ->
      HS.notify hoverSub.listener
        (NodeHovered nodeId)
    void $ H.subscribe hoverSub.emitter
    result <- liftAff loadGraphData
    case result of
      Left err ->
        H.modify_ _ { error = Just err }
      Right graph -> do
        let start = mostConnectedNode graph
        H.modify_ _
          { graph = graph
          , selected = start
          }
        renderGraph

  NodeTapped nodeId -> do
    state <- H.get
    let node = Map.lookup nodeId state.graph.nodes
    H.modify_ _ { selected = node }
    renderGraph

  NodeHovered nodeId -> do
    state <- H.get
    let node = Map.lookup nodeId state.graph.nodes
    H.modify_ _ { selected = node }
    liftEffect $ Cy.markRoot nodeId

  SetDepth d -> do
    H.modify_ _ { depth = d }
    renderGraph

  FitAll ->
    liftEffect Cy.fitAll

  NavigateTo nodeId -> do
    state <- H.get
    let node = Map.lookup nodeId state.graph.nodes
    H.modify_ _ { selected = node }
    renderGraph

renderGraph
  :: forall o
   . H.HalogenM State Action () o Aff Unit
renderGraph = do
  state <- H.get
  let
    visible = case state.selected of
      Just node ->
        let
          hood = neighborhood state.depth
            node.id
            state.graph
        in
          subgraph hood state.graph
      Nothing -> state.graph

  liftEffect $ Cy.setFocusElements
    (GCy.toElements visible)
  for_ state.selected \node ->
    liftEffect $ Cy.markRoot node.id

-- | Find the node with the most connections.
mostConnectedNode :: Graph -> Maybe Node
mostConnectedNode graph =
  let
    edges = graph.edges
    counts = foldl countEdge Map.empty edges
    best = foldl
      ( \acc (Tuple nid count) ->
          case acc of
            Nothing -> Just (Tuple nid count)
            Just (Tuple _ best') ->
              if count > best'
                then Just (Tuple nid count)
                else acc
      )
      Nothing
      (Map.toUnfoldable counts :: Array _)
  in
    case best of
      Just (Tuple nid _) ->
        Map.lookup nid graph.nodes
      Nothing -> Nothing
  where
  countEdge m edge =
    let
      m1 = Map.alter (Just <<< add 1 <<< orZero) edge.source m
      m2 = Map.alter (Just <<< add 1 <<< orZero) edge.target m1
    in
      m2
  orZero Nothing = 0
  orZero (Just n) = n

loadGraphData :: Aff (Either String Graph)
loadGraphData = do
  resp <- fetch "data/graph.json" { method: GET }
  body <- resp.text
  pure case jsonParser body of
    Left err -> Left err
    Right json -> decodeGraph json

-- Helpers

depthBtn
  :: forall m
   . Int
  -> Int
  -> H.ComponentHTML Action () m
depthBtn n current =
  HH.button
    [ cls
        ( "depth-btn"
            <> if n == current then " active"
              else ""
        )
    , HE.onClick \_ -> SetDepth n
    ]
    [ HH.text (show n) ]

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
