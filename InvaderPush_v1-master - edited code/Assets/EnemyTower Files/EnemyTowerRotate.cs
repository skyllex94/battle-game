using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EnemyTowerRotate : MonoBehaviour {

    [Header("Showing the closest enemy to the Tower")]
    public Transform target;

    [Header("Attributes")]
    public float range = 10f;
    public float fireRate = 1f;
    private float fireCountdown = 0f;

    [Header("Setup Fields")]
    public string enemytag = "Player";
    public Transform HeadRotation;
    public GameObject TowerBulletPrefab;
    public Transform firePoint;
    public float turnSpeed = 10;

    Rigidbody2D rb;


    void Start()
    {
        InvokeRepeating("UpdateTarget", 0f, 0.5f);
    }


    // Update is called once per frame
    void Update()
    {

        if (target == null)
            return;

        Vector3 dir = target.position - transform.position;
        Quaternion lookRotation = Quaternion.LookRotation(dir);
        // Vector3 rotation = Quaternion.Lerp(HeadRotation.rotation, lookRotation, Time.deltaTime * turnSpeed).eulerAngles;
        Vector3 rotation = lookRotation.eulerAngles;
        HeadRotation.rotation = Quaternion.Euler(rotation.x, rotation.y, rotation.z);

        if (fireCountdown <= 0f)
        {
            Shoot();
            fireCountdown = 1f / fireRate;
        }
        fireCountdown -= Time.deltaTime;
    }

    void Shoot()
    {
        GameObject bulletGO = (GameObject)Instantiate(TowerBulletPrefab, firePoint.position, firePoint.rotation);
        EnemyTowerBulletMovement bullet = bulletGO.GetComponent<EnemyTowerBulletMovement>();
        if (bullet != null)
        {
            bullet.Seek(target);
            Destroy(bulletGO, 4f);
        }
    }

    void UpdateTarget()
    {
        GameObject[] enemies = GameObject.FindGameObjectsWithTag(enemytag);
        float shortestDistance = Mathf.Infinity;
        GameObject nearestEnemy = null;

        foreach (GameObject enemy in enemies)
        {
            float distanceToEnemy = Vector3.Distance(transform.position, enemy.transform.position);
            if (distanceToEnemy < shortestDistance)
            {
                shortestDistance = distanceToEnemy;
                nearestEnemy = enemy;
            }
        }
        
        if (nearestEnemy != null && shortestDistance <= range)
        {
            target = nearestEnemy.transform;
        }
        else
        {
            target = null;
        }
    }

    void OnDrawGizmosSelected()
    {
        Gizmos.color = Color.red;
        Gizmos.DrawWireSphere(transform.position, range);
    }
}
