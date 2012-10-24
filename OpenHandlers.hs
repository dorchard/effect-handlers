{- Parameterised open handlers with parameterised operations

   This version has two type families for specifying the return type
   of operations and the result type of handlers. Only one type class
   is declared. Its instances define handler clauses.

   Parameters should be stored in operations and handlers. Thus the
   handler and op arguments to the clause function can be used to
   actually pass parameters, and not just to work around weaknesses in
   type inference. Note that this also means an arbitrary number of
   parameters can be easily attached to an operation or handler

   The return clause is passed in as an argument to the handle
   function.

   We support polymorphic operations straightforwardly by defining a 
   further type class (PolyHandles).
-}

{-# LANGUAGE TypeFamilies,
    MultiParamTypeClasses,
    TypeOperators,
    NoMonomorphismRestriction #-}

module OpenHandlers where

-- we might consider defining the following type synonym for handlers:
--
--   type Handler h a = (h, Cont h a)

type family Return op :: *
type family Result h :: *

type Cont h a = h -> a -> Result h

class Handles h op where
  clause :: h -> op -> Cont h (Return op) -> Result h

newtype Comp h a = Comp {handle :: h -> Cont h a -> Result h}

instance Monad (Comp h) where
  return v     = Comp (\h k -> k h v)
  Comp c >>= f = Comp (\h k -> c h (\h' x -> handle (f x) h' k))

instance Functor (Comp h) where
  fmap f c = c >>= return . f

doOp :: (h `Handles` op) => op -> Comp h (Return op)
doOp op = Comp (\h k -> clause h op k)

forward :: (h `Handles` op) => h' -> op -> (h' -> Return op -> Comp h a) -> Comp h a
forward h op k = doOp op >>= k h

-- polymorphic operations
class (h `PolyHandles` op) where
  polyClause :: h -> op a -> Cont h (Return (op a)) -> Result h

polyDoOp :: (h `PolyHandles` op) => op a -> Comp h (Return (op a))
polyDoOp op = Comp (\h k -> polyClause h op k)

-- pure handlers
data PureHandler a = PureHandler
type instance Result (PureHandler a) = a

handlePure :: Comp (PureHandler a) a -> a
handlePure c = handle c PureHandler (const id)

data Get s = Get
type instance Return (Get s) = s
get = doOp Get

newtype Put s = Put s
type instance Return (Put s) = ()
put s = doOp (Put s)

newtype StateHandler s a = StateHandler s
type instance Result (StateHandler s a) = a
instance (StateHandler s a `Handles` Get s) where
  clause (StateHandler s) Get k = k (StateHandler s) s
instance (StateHandler s a `Handles` Put s) where
  clause _ (Put s) k = k (StateHandler s) ()

countTest =
    do {n <- get;
        if n == (0 :: Int) then return ()
        else do {put (n-1); countTest}}