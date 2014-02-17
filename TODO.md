Submit to repo

Think about how parse fits in?
- Constant daemon, every 100 seconds parse a file??
- Run on it's own node
- some system so load is shared, ie same data not parsed. by two nodes. This should be ok- as db is updated immediately. Could use flock.

Push to cluster
- What hashsize?? Use multiple nodes??
- How much space am I allowed??
- How to get db back?!
- Does multiple sql servers work ok??
- Start with a few PGNs.
