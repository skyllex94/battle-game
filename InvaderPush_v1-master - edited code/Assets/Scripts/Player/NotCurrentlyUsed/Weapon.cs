using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.EventSystems;

public class Weapon : MonoBehaviour {

    public float fireRate = 0;
    public int Damage = 10;
    public LayerMask whatToHit;

    public Transform BulletTrailPrefab;
    public Transform MuzzleFlashPrefab;
    public Transform HitPrefab;
    float TimeToSpawnEffect = 0;
    public float effectSpawnRate = 10;
    public float timeToFire = 0;
    Transform firePoint;

    public float camShakeAmt = 0.05f; // handle Camera Shake
    public float camLength = 0.1f;
    CameraShake camShake;

	void Awake () {
        firePoint = transform.Find("FirePoint");
        if (firePoint == null)
        {
            Debug.LogError("The array firepoint is not working!");
        }
	}

    void Start()
    {
        camShake = GameMaster.gm.GetComponent<CameraShake>();
        if (camShake == null)
        {
            Debug.LogError("NO camera shake!");
        }
    }
	
	void Update () {
        if (fireRate == 0)
        {
            if (Input.GetButtonDown("Fire1") && Time.time > timeToFire)
            {
                Shoot();
            }
            else if (Input.GetButtonDown("Fire1") && Time.time > timeToFire)
            {
                timeToFire = Time.time + 1 / fireRate;
                Shoot();
            }
        }
	}

    public void Shoot()
    {
        if (IsPointerOverUIObject())
        {
            //Vector2 mousePosition = new Vector2(Camera.main.ScreenToWorldPoint(Input.GetTouch(0).position).x, Camera.main.ScreenToWorldPoint(Input.GetTouch(0).position).y);

               Vector2 mousePosition = new Vector2(Camera.main.ScreenToWorldPoint(Input.mousePosition).x, Camera.main.ScreenToWorldPoint(Input.mousePosition).y);
               Vector2 firePointPosition = new Vector2 (firePoint.position.x, firePoint.position.y);

               RaycastHit2D Hit = Physics2D.Raycast(firePointPosition, mousePosition - firePointPosition, 100, whatToHit);
        
               //Debug.DrawLine(firePointPosition, (mousePosition - firePointPosition) * 100, Color.red);
               if (Hit.collider != null)
               {
                   Debug.DrawLine(firePointPosition, Hit.point, Color.red);
                // Debug.Log ("we hit " + Hit.collider.name + Damage);
                   Enemy enemy = Hit.collider.GetComponent<Enemy>();
                   EnemyTower enemytower = Hit.collider.GetComponent<EnemyTower>();
                   EnemyBase enemybase = Hit.collider.GetComponent<EnemyBase>();
                   if (enemy != null)
                   {
                       enemy.DamageEnemy(Damage);
                   }
                   if (enemytower != null)
                   {
                       enemytower.DamageEnemyTower(Damage);
                   }
                   if (enemybase != null)
                   {
                       enemybase.DamageEnemyBase(Damage);
                   }
               }

               if (Time.time >= TimeToSpawnEffect)
               {
                   Vector3 hitPos;
                   Vector3 hitNormal;
                   if (Hit.collider == null)
                   {
                       hitPos = (mousePosition - firePointPosition) * 30;
                       hitNormal = new Vector3(9999, 9999, 9999);
                   }
                   else
                   {
                       hitPos = Hit.point;
                       hitNormal = Hit.normal;
                   }
               
                   Effect(hitPos, hitNormal);
                   TimeToSpawnEffect = Time.time + 1 / effectSpawnRate;
            }
        }
    }

    //When Touching UI
    private bool IsPointerOverUIObject()
    {
        PointerEventData eventDataCurrentPosition = new PointerEventData(EventSystem.current);
        eventDataCurrentPosition.position = new Vector2(Input.mousePosition.x, Input.mousePosition.y);
        List<RaycastResult> results = new List<RaycastResult>();
        EventSystem.current.RaycastAll(eventDataCurrentPosition, results);
        return results.Count > 0;
    }

    void Effect(Vector3 hitPos, Vector3 hitNormal)
    {
        Transform trail = Instantiate (BulletTrailPrefab, firePoint.position, firePoint.rotation) as Transform;
        LineRenderer lr = trail.GetComponent<LineRenderer>();
        if (lr != null)
        {
            lr.SetPosition(0, firePoint.position);
            lr.SetPosition(1, hitPos);
            
        }
        Destroy(trail.gameObject, 5.00f);
        if (hitNormal != new Vector3(9999, 9999, 9999))
        {
            Transform hitParticle = Instantiate (HitPrefab, hitPos, Quaternion.FromToRotation(Vector3.right, hitNormal)) as Transform;
            Destroy (hitParticle.gameObject, 1f);
        }
        Transform clone = Instantiate(MuzzleFlashPrefab, firePoint.position, firePoint.rotation) as Transform;
        clone.parent = firePoint;
        float size = Random.Range(0.6f, 0.9f);
        clone.localScale = new Vector3(size, size, size);
        Destroy(clone.gameObject,0.02f);
        camShake.Shake(camShakeAmt,camLength);
    }
}
