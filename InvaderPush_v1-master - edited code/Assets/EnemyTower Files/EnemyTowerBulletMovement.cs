using UnityEngine;

public class EnemyTowerBulletMovement : MonoBehaviour {

    private Transform target;
    public float speed = 70f;
    public GameObject ImpactBulletEffect;
    public int damageEnemyFromTowerAmount = 30;
    Vector3 dir;

    public void Seek(Transform _target)
    {
        target = _target;
        dir = target.position - transform.position;
    }

    void Update()
    {
        float distanceThisFrame = speed * Time.deltaTime;

        if (dir.magnitude <= distanceThisFrame)
        {
            HitTarget();
            return;
        }
        transform.Translate(dir.normalized * distanceThisFrame, Space.World);
    }

    void HitTarget()
    {
        GameObject effectIns = (GameObject)Instantiate(ImpactBulletEffect, transform.position, transform.rotation);
        Destroy(effectIns, 1f);
        Destroy(gameObject);
        //Damage(target);
    }

    void Damage(Transform player)
    {  // Function for calling the GameObject found & damaging "enemies" appoximately to the public variable
        Player p = player.GetComponent<Player>();
        Allies a = player.GetComponent<Allies>();
        if (p != null)
        {
            p.DamagePlayer(damageEnemyFromTowerAmount);
        }
        if (a != null)
        {
            a.DamageAlly(damageEnemyFromTowerAmount);
        }
        //Destroy(p.gameObject);
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        Player p = other.GetComponent<Player>();
        Allies a = other.GetComponent<Allies>();
        Tower t = other.GetComponent<Tower>();
        if (p != null)
        {
            HitTarget();
            p.DamagePlayer(damageEnemyFromTowerAmount);
        }
        if (a != null)
        {
            HitTarget();
            a.DamageAlly(damageEnemyFromTowerAmount);
        }
        if (t != null)
        {
            HitTarget();
            t.DamageTower(damageEnemyFromTowerAmount);
        }
        Destroy(gameObject);
    }
}
