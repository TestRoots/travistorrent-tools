select u.login, p.name, p.language, count(*)
from projects p, users u, watchers w
where
    p.forked_from is null and
    p.deleted is false and
    w.repo_id = p.id and
    u.id = p.owner_id and 
    p.language = "Java"
group by p.id
having count(*) > 50
order by count(*) desc