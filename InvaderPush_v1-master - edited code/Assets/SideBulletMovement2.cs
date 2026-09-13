using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class SideBulletMovement2 : MonoBehaviour {

    private Vector3 target;
    private Transform thesideTarget;
    public float speed = 70f;
    public GameObject ImpactBulletEffect;
    public int damageEnemyFromBaseAmount = 30;


    public void Seek(Vector3 _target)
    {
        target = _target;
    }

    void Update()
    {
        //Vector3 dir = target.position - transform.position;

        Vector3 sidePos = new Vector3(target.x, target.y, target.z);
        Vector3 sideMovement = sidePos - transform.position;
        //GetComponent<Rigidbody2D>().velocity = sideMovement;

        float distanceThisFrame = speed * Time.deltaTime;
        transform.Translate(sideMovement.normalized * distanceThisFrame, Space.World);

        /* if (sidePos.magnitude <= distanceThisFrame)
         {
           
             return;
         } */


        //HitTarget();
        // Vector3 dir2 = sidePos - transform.position;
        // sidePos = target.position;
        //sidePos.y += 90;

        //transform.Translate(dir.normalized * distanceThisFrame, Space.World);


    }


    void HitTarget()
    {
        GameObject effectIns = (GameObject)Instantiate(ImpactBulletEffect, transform.position, transform.rotation);
        Destroy(effectIns, 1f);
        Destroy(gameObject);
        //Damage(target);
    }

    void Damage(Transform enemy)
    {  // Function for calling the GameObject found & damaging "enemies" appoximately to the public variable
        Enemy e = enemy.GetComponent<Enemy>();
        if (e != null)
        {
            e.DamageEnemy(damageEnemyFromBaseAmount);
        }
        //Destroy(enemy.gameObject);
    }

    void OnTriggerEnter2D(Collider2D other)
    {
        Enemy enemy = other.GetComponent<Enemy>();
        EnemyTower etower = other.GetComponent<EnemyTower>();
        if (other.tag == "Enemies")
        {
            HitTarget();
            enemy.DamageEnemy(damageEnemyFromBaseAmount);
            //Destroy(gameObject);
        }
        if (other.tag == "EnemyTower")
        {
            HitTarget();
            etower.DamageEnemyTower(damageEnemyFromBaseAmount);
        }
        Destroy(gameObject);
    }
}
