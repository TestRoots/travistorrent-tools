Query used to select projects

```sql
select u.login, p.name, p.language, count(*)
from projects p, users u, watchers w
where
    p.forked_from is null and
    p.deleted is false and
    w.repo_id = p.id and
    u.id = p.owned_id and
    p.language in ('Java', 'Ruby', 'Python', 'Scala')
group by p.id
having count(*) > 50
```