using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EnemyBaseMovement : MonoBehaviour {

    private Transform target;
    public float speed = 70f;
    public GameObject ImpactBulletEffect;
    public int damageEnemyFromBaseAmount = 30;
    Vector3 dir;

    public void Seek(Transform _target)
    {
        target = _target;
        dir = target.position - transform.position;

        // Vector3 sidePos = new Vector3 (target.position.x, target.position.y + 90, target.position.z);
        // Vector3 dir2 = sidePos - transform.position;
        // sidePos = target.position;
        //sidePos.y += 90;
        //transform.Translate(sidePos.normalized * distanceThisFrame, Space.World);
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

    void OnTriggerEnter2D(Collider2D other)
    {
        Player player = other.GetComponent<Player>();
        Tower tower = other.GetComponent<Tower>();
        Allies allie = other.GetComponent<Allies>();
        if (player != null)
        {
            HitTarget();
            player.DamagePlayer(damageEnemyFromBaseAmount);
        }
        if (tower != null)
        {
            HitTarget();
            tower.DamageTower(damageEnemyFromBaseAmount);
        }
        if (allie != null)
        {
            HitTarget();
            allie.DamageAlly(damageEnemyFromBaseAmount);
        }
        Destroy(gameObject);
    }
}
