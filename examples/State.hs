{-# LANGUAGE TypeFamilies,
    RankNTypes,
    MultiParamTypeClasses, 
    FlexibleContexts, 
    QuasiQuotes,
    TypeOperators,
    ScopedTypeVariables #-}

import Control.Monad
import Data.IORef
import Handlers
import DesugarHandlers

[operation|Get s :: s|]
[operation|Put s :: s -> ()|]

type SComp s a =
  (h `Handles` Get s, h `Handles` Put s) => Comp h a

[handler|
  MonadicState s a :: s -> (a, s)
    handles {Get s, Put s} where
      Return  x     s -> (x, s)
      Get        k  s -> k s  s
      Put     s  k  _ -> k () s
|] 
[handler|
  SimpleState s a :: s -> a 
    handles {Get s, Put s} where
      Return  x     _ -> x
      Get        k  s -> k s  s
      Put     s  k  _ -> k () s
|]
[handler|
  LogState s a :: [s] -> s -> (a, [s])
    handles {Get s, Put s} where
      Return  x      ss s -> (x, reverse (s:ss))
      Get         k  ss s -> k s  ss     s
      Put     s'  k  ss s -> k () (s:ss) s'
|]
[handler|
  IORefState s a :: IORef s -> IO a
    handles {Get s, Put s} where
      Return  x     _ -> return x
      Get        k  r -> do {s <- readIORef r; k s r}
      Put     s  k  r -> do {writeIORef r s; k () r}
|]

comp1 :: SComp Int Int
comp1 = do {  (x::Int) <- get; put (x+1);
              (y::Int) <- get; put (y+y); get}

test1 = monadicState (1::Int) comp1
test2 = simpleState (1::Int) comp1
test3 = logState [] (1::Int) comp1
test4 = do {r <- newIORef (1::Int); iORefState r comp1}

-- *Main> monadicState (1 :: Int) comp1
-- (4, 4)

-- *Main> simpleState (1 :: Int) comp1
-- 4

-- *Main> logState [] (1 :: Int) comp1
-- (4, [1, 2, 4])

-- *Main> do {r <- newIORef (1::Int); iORefState r comp1}
-- 4
