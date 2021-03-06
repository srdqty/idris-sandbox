import Control.Monad.State

data Store i k v = MkStore i (k -> v)

initialise : i -> (k -> v) -> Store i k v
initialise = MkStore

getInfo : Store i k v -> i
getInfo (MkStore i _) = i

putInfo : i -> Store i k v -> Store i k v
putInfo i (MkStore _ f) = MkStore i f

getValue : k -> Store i k v -> v
getValue k (MkStore _ f) = f k

putValue : Eq k => k -> v -> Store i k v -> Store i k v
putValue k v (MkStore i f) = MkStore i (\k' => if k == k' then v else f k')

data Hash v = MkHash v

hash : v -> Hash v
hash v = MkHash v

getHash : k -> Store i k v -> Hash v
getHash k (MkStore _ f) = hash (f k)

Constraint : Type
Constraint = (Type -> Type) -> Type

data Task : Constraint -> Type -> Type -> Type where
  MkTask : ({f : _} -> c f => (c f => k -> f v) -> f v) -> Task c k v

Tasks : Constraint -> Type -> Type -> Type
Tasks c k v = k -> Maybe (Task c k v)

Build : Constraint -> Type -> Type -> Type -> Type
Build c i k v = Tasks c k v -> k -> Store i k v -> Store i k v

Rebuilder : Constraint -> Type -> Type -> Type -> Type
Rebuilder c ir k v = k -> v -> Task c k v -> Task (MonadState ir) k v

Scheduler : Constraint -> Type -> Type -> Type -> Type -> Type
Scheduler c i ir k v = Rebuilder c ir k v -> Build c i k v

sprsh1 : Tasks Applicative String Integer
sprsh1 "B1" = Just (MkTask (\fetch => liftA2 (+) (fetch "A1") (fetch "A2")))
sprsh1 "B2" = Just (MkTask (\fetch => liftA (*2) (fetch "B1")))
sprsh1 _ = Nothing

busy : Eq k => Build Applicative () k v
busy {k} {v} tasks key store = execState (fetch key) store
  where
    fetch : k -> State (Store () k v) v
    fetch key = case tasks key of
      Nothing => gets (getValue key)
      Just (MkTask task) => do
        val <- task fetch
        modify (putValue key val)
        pure val

store : Store () String Integer
store = initialise () (\key => if key == "A1" then 10 else 20)

result : Store () String Integer
result = busy sprsh1 "B2" store

b1 : Integer
b1 = getValue "B1" result

b2 : Integer
b2 = getValue "B2" result

data ConstA a b = MkConst a

getConst : ConstA a b -> a
getConst (MkConst x) = x

Functor (ConstA a) where
  map _ (MkConst x) = (MkConst x)

Monoid a => Applicative (ConstA a) where
  pure _ = MkConst neutral
  (<*>) (MkConst x) (MkConst y) = MkConst (x <+> y)

deps : Task Applicative k v -> List k
deps (MkTask f) = getConst $ f (\k => MkConst [k])

b1Deps : Maybe (List String)
b1Deps = deps <$> sprsh1 "B1"

b2Deps : Maybe (List String)
b2Deps = deps <$> sprsh1 "B2"
