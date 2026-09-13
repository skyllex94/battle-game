using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;
public class EnemyBaseRotation : MonoBehaviour {

    [Header("Showing the closest enemy to the Base")]
    public Transform target;

    [Header("Attributes")]
    public float range = 12f;
    public float fireRate = 1f;
    private float fireCountdown = 0f;

    [Header("Setup Fields")]
    public string enemytag;
    public Transform HeadRotation;
    public GameObject BaseBulletPrefab;
    public GameObject SideBullet1;
    public GameObject SideBullet2;
    public Transform firePoint;
    public float turnSpeed = 10;

    public Vector3 sidedirr;
    public Vector3 sidedirr2;

    
    void Start()
    {
        InvokeRepeating("UpdateTarget", 0f, 0.5f);
    }

    void Update()
    {
        if (target == null)
            return;

        Vector3 dir = target.position - transform.position;
        
        Quaternion lookRotation = Quaternion.LookRotation(dir);
        Vector3 rotation = Quaternion.Lerp(HeadRotation.rotation, lookRotation, Time.deltaTime * turnSpeed).eulerAngles;
        // Vector3 rotation = lookRotation.eulerAngles;

        HeadRotation.rotation = Quaternion.Euler(rotation.x, rotation.y, rotation.z);

        Vector3 yeah = new Vector3(HeadRotation.rotation.x, HeadRotation.rotation.y + 3, HeadRotation.rotation.z);
        Vector3 yeah2 = new Vector3(HeadRotation.rotation.x, HeadRotation.rotation.y - 66, HeadRotation.rotation.z);

        sidedirr = yeah - transform.position;
        sidedirr2 = yeah2 - transform.position;

        if (fireCountdown <= 0f)
        {
            Shoot();
            fireCountdown = 1f / fireRate;
        }
        fireCountdown -= Time.deltaTime;
    }

    void Shoot()
    {
        GameObject bulletGO = (GameObject)Instantiate(BaseBulletPrefab, firePoint.position, firePoint.rotation);
        GameObject sidebullet = (GameObject)Instantiate(SideBullet1, firePoint.position, firePoint.rotation);
        GameObject sidebullet2 = (GameObject)Instantiate(SideBullet2, firePoint.position, firePoint.rotation);

        EnemyBaseMovement bullet = bulletGO.GetComponent<EnemyBaseMovement>();
        EnemySideBulletMovement sidebulletmove = sidebullet.GetComponent<EnemySideBulletMovement>();
        EnemySideBulletMovement2 sidebulletmove2 = sidebullet2.GetComponent<EnemySideBulletMovement2>();

        if (bullet != null)
        {
            bullet.Seek(target);
            Destroy(bulletGO, 2f);
        }

        if (sidebulletmove != null)
        {
            sidebulletmove.Seek(sidedirr);
            Destroy(sidebullet, 2f);
        }
        if (sidebulletmove2 != null)
        {
            sidebulletmove2.Seek(sidedirr2);
            Destroy(sidebullet2, 2f);
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
