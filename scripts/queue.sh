#!/bin/bash
case $1 in
  push)
	  psql --tuples-only --quiet --no-align --field-separator=' ' -c "select queue_push('$2')" > /dev/null
    ;;
  pop)
	  psql --tuples-only --quiet --no-align --field-separator=' ' -c 'select queue_pop()'
    ;;
  len)
	  psql --tuples-only --quiet --no-align --field-separator=' ' -c 'select queue_len()'
    ;;
  *)
    ;;
esac
