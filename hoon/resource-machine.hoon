|%
::  resource machine data structures
::  a resource. see resource machine report
+$  resource
  $:
    logic=resource-logic
    label=@t
    quantity=@
    data=@
    eph=?
    nonce=@
    npk=@
    rseed=@
  ==
::  a transparent resource commitment is the resource.
+$  commitment  resource
::  a transparent nullifier is the resource, signed by the nullifier key
+$  nullifier  [resource=resource signature=@]
::  a transparent proof is the resource (just the resource logic, really)
+$  proof  resource
::  a delta is a signed denominated amount. denom depends on logic and label
::  true = positive; todo: use map instead (when hashes are in)
+$  delta  (list [denom=@ sign=? amount=@])
++  zero-delta  `delta`~
::  a resource transaction. see the resource machine report
+$  resource-transaction  ::  todo: sets instead of lists
  $:
    roots=(list @)
    commitments=(list commitment)
    nullifiers=(list nullifier)
    proofs=(list proof)
    delta=delta  ::  total tx delta
    extra=@
    preference=preference-function
  ==
::  a resource logic is a function from a transaction to boolean
+$  resource-logic
  $-(resource-transaction ?)
::  currently unused
+$  preference-function
  $-(resource-transaction @)
::  operations for use in resource logics
++  spent-resources
  |=  l=(list nullifier)
  ^-  (list resource)
  ::  todo: allow signature checking here
  (turn l |=([resource=resource signature=@] resource))
++  created-resources
  |=  l=(list commitment)
  ^-  (list resource)
  l
++  delta-add
  |=  [a=delta b=delta]
  ^-  delta
  !!
++  delta-sub
  |=  [a=delta b=delta]
  ^-  delta
  !!
--
|%
++  example-logic-balanced
  ::  delta balance is checked at the validity level anyway,
  ::  this logic should be entirely redundant.
  ::  just making sure it's checkable in a logic
  ^-  resource-logic
  |=  tx=resource-transaction
  ^-  ?
  =/  created  (created-resources commitments.tx)
  =/  spent  (spent-resources nullifiers.tx)
  =/  created-sum  (foldr created delta-add)
  =/  spent-sum  (foldr spent delta-add)
  =(delta.tx (delta-sub created-sum spent-sum)
++  example-logic-one-for-one
  ::  only allow a balanced one for one transaction
  ^-  resource-logic
  |=  tx=resource-transaction
  ^-  ?
  =/  created  (created-resources commitments.tx)
  =/  spent  (spent-resources nullifiers.tx)
  ?.  =(1 (length created))  |
  ?.  =(1 (length spent))  |
  ?.  =(zero-delta delta.tx)  |
  &
++  example-logic-counter
  ^-  resource-logic
  |=  tx=resource-transaction
  ^-  ?
  =/  created  (created-resources commitments.tx)
  =/  spent  (spent-resources nullifiers.tx)
  ?.  =(1 (length created))  |
  ?.  =(1 (length spent))  |
  ?~  created  |
  ?~  spent  |
  =/  old-ctr  i.spent
  =/  new-ctr  i.created
  ?.  =(label.new-ctr label.old-ctr)  |
  ?.  (gth quantity.new-ctr quantity.old-ctr)  |
  &
--