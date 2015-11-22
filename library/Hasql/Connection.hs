-- |
-- This module provides a low-level effectful API dealing with the connections to the database.
module Hasql.Connection
(
  Connection,
  ConnectionError(..),
  connect,
  disconnect,
)
where

import Hasql.Connection.Impl
