{-# LANGUAGE TypeOperators, OverloadedStrings #-}
module Graphics where

import Data.ByteString.Char8 (ByteString)
import Data.List

import LC_API
--import LCLanguage

import Material

cull = CullNone

-- specialized snoc
v3v4 :: Exp s V3F -> Exp s V4F
v3v4 v = let V3 x y z = unpack' v in pack' $ V4 x y z (Const 1)

v4v3 :: Exp s V4F -> Exp s V3F
v4v3 v = let V4 x y z _ = unpack' v in pack' $ V3 x y z

-- specialized snoc
snoc :: Exp s V3F -> Float -> Exp s V4F
snoc v s = let V3 x y z = unpack' v in pack' $ V4 x y z (Const s)

drop4 :: Exp s V4F -> Exp s V3F
drop4 v = let V4 x y z _ = unpack' v in pack' $ V3 x y z

drop3 :: Exp s V3F -> Exp s V2F
drop3 v = let V3 x y _ = unpack' v in pack' $ V2 x y

{-
data WaveType
    = WT_Sin
    | WT_Triangle
    | WT_Square
    | WT_Sawtooth
    | WT_InverseSawtooth
    | WT_Noise

data Wave = Wave !WaveType !Float !Float !Float !Float

data Deform
    = D_AutoSprite
    | D_AutoSprite2
    | D_Bulge !Float !Float !Float
    | D_Move !Vec3 !Wave
    | D_Normal !Float !Float
    | D_ProjectionShadow
    | D_Text0
    | D_Text1
    | D_Text2
    | D_Text3
    | D_Text4
    | D_Text5
    | D_Text6
    | D_Text7
    | D_Wave !Float !Wave

data CommonAttrs
    = CommonAttrs
    { caSkyParms        :: !()
    , caFogParms        :: !()
    , caPortal          :: !Bool
    , caSort            :: !Int             -- done
    , caEntityMergable  :: !Bool
    , caFogOnly         :: !Bool
    , caCull            :: !()
    , caDeformVertexes  :: ![Deform]
    , caNoMipMaps       :: !Bool
    , caPolygonOffset   :: !Bool            -- done
    , caStages          :: ![StageAttrs]
    }

data StageAttrs
    = StageAttrs
    { saBlend       :: !(Maybe (Blending,Blending))
    , saRGBGen      :: !RGBGen
    , saAlphaGen    :: !AlphaGen
    , saTCGen       :: !TCGen
    , saTCMod       :: ![TCMod]
    , saTexture     :: !StageTexture
    , saDepthWrite  :: !Bool
    , saDepthFunc   :: !DepthFunction
    , saAlphaFunc   :: !(Maybe AlphaFunction)
    }
-}

-- TODO: requires texture support
deform :: Deform -> Exp V a -> Exp V a
deform = undefined

mkShader :: GP (FrameBuffer N1 (Float,V4F)) -> (ByteString,CommonAttrs) -> GP (FrameBuffer N1 (Float,V4F))
mkShader fb (name,ca) = Accumulate fragCtx PassAll frag rast fb
  where
    offset  = if caPolygonOffset ca then Offset (-1) (-2) else NoOffset
    fragCtx = DepthOp Less True:.ColorOp NoBlending (one' :: V4B):.ZT
    rastCtx = TriangleCtx cull PolygonFill offset LastVertex
    rast    = Rasterize rastCtx prims
    prims   = Transform vert input
    input   = Fetch name Triangle (IV3F "position", IV3F "normal", IV2F "diffuseUV", IV2F "lightmapUV", IV4F "color")
    worldViewProj = Uni (IM44F "worldViewProj")

    vert :: Exp V (V3F,V3F,V2F,V2F,V4F) -> VertexOut V4F
    vert pndlc = VertexOut v4 (Const 1) (Smooth c:.ZT)
      where
        v4    = worldViewProj @*. snoc p 1
        (p,n,d,l,c) = untup5 pndlc

    frag :: Exp F V4F -> FragmentOut (Depth Float :+: Color V4F :+: ZZ)
    frag a = FragmentOutRastDepth $ a :. ZT

q3GFX :: [(ByteString,CommonAttrs)] -> GP (FrameBuffer N1 (Float,V4F))
q3GFX shl = errorShader $ foldl' mkShader clear ordered
  where
    ordered = sortBy (\(_,a) (_,b) -> caSort a `compare` caSort b) shl
    clear   = FrameBuffer (DepthImage n1 1000:.ColorImage n1 (zero'::V4F):.ZT)

errorShader :: GP (FrameBuffer N1 (Float,V4F)) -> GP (FrameBuffer N1 (Float,V4F))
errorShader fb = Accumulate fragCtx PassAll frag rast $ errorShaderFill fb
  where
    offset  = NoOffset--Offset (0) (-10)
    fragCtx = DepthOp Lequal True:.ColorOp NoBlending (one' :: V4B):.ZT
    rastCtx = TriangleCtx cull (PolygonLine 2) offset LastVertex
    rast    = Rasterize rastCtx prims
    prims   = Transform vert input
    input   = Fetch "missing shader" Triangle (IV3F "position", IV4F "color")
    worldViewProj = Uni (IM44F "worldViewProj")

    vert :: Exp V (V3F,V4F) -> VertexOut V4F
    vert pc = VertexOut v4 (Const 1) (Smooth c:.ZT)
      where
        v4    = worldViewProj @*. snoc p 1
        (p,c) = untup2 pc

    frag :: Exp F V4F -> FragmentOut (Depth Float :+: Color V4F :+: ZZ)
    frag v = FragmentOutRastDepth $ (v @* (Const (V4 3 3 3 1) :: Exp F V4F)) :. ZT
      where
        V4 r g b a = unpack' v

errorShaderFill :: GP (FrameBuffer N1 (Float,V4F)) -> GP (FrameBuffer N1 (Float,V4F))
errorShaderFill fb = Accumulate fragCtx PassAll frag rast fb
  where
    blend   = NoBlending
    fragCtx = DepthOp Less True:.ColorOp blend (one' :: V4B):.ZT
    rastCtx = TriangleCtx cull PolygonFill NoOffset LastVertex
    rast    = Rasterize rastCtx prims
    prims   = Transform vert input
    input   = Fetch "missing shader" Triangle (IV3F "position", IV4F "color")
    worldViewProj = Uni (IM44F "worldViewProj")

    vert :: Exp V (V3F,V4F) -> VertexOut V4F
    vert pc = VertexOut v4 (Const 1) (Smooth c:.ZT)
      where
        v4    = worldViewProj @*. snoc p 1
        (p,c) = untup2 pc

    frag :: Exp F V4F -> FragmentOut (Depth Float :+: Color V4F :+: ZZ)
    frag v = FragmentOutRastDepth $ v :. ZT

{-
identity - RGBA 1 1 1 1
identity_lighting (identity_light_byte = ilb) - RGBA ilb ilb ilb ilb
lighting_diffuse - ??? check: RB_CalcDiffuseColor
exact_vertex - vertex color
const - constant color
vertex (identity_light = il, vertex_color*il) - RGBA (r*il) (g*il) (b*il) a
one_minus_vertex = (identity_light = il, vertex_color*il) - RGBA ((1-r)*il) ((1-g)*il) ((1-b)*il) a
fog - fog color
waveform (c = clamp 0 1 (wave_value * identity_light)) - RGBA c c c 1
entity - entity's shaderRGB
one_minus_entity - 1 - entity's shaderRGB
-}
{-
rgbExactVertex _ (_,_,_,r:.g:.b:._:.()) = r:.g:.b:.()
rgbVertex _ (_,_,_,r:.g:.b:._:.()) = f r:.f g:.f b:.()
  where
    f a = toGPU identityLight * a
rgbOneMinusVertex _ (_,_,_,r:.g:.b:._:.()) = f r:.f g:.f b:.()
  where
    f a = 1 - toGPU identityLight * a
-- time vertexData
--convRGBGen :: RGBGen -> 
convRGBGen a = case a of
    RGB_Const r g b      -> Const $ V3 r g b
    RGB_Identity         -> Const $ V3 1 1 1
    RGB_IdentityLighting -> Const $ V3 identityLight identityLight identityLight
    RGB_ExactVertex      -> rgbExactVertex
    RGB_Vertex           -> rgbVertex
    RGB_OneMinusVertex   -> rgbOneMinusVertex
    _   -> rgbIdentity
--    RGB_Wave w          
--    RGB_Entity
--    RGB_OneMinusEntity
--    RGB_LightingDiffuse
-}