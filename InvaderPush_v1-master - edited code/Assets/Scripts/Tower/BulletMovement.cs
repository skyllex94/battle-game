using UnityEngine;

public class BulletMovement : MonoBehaviour {

    private Transform target;
    public float speed = 70f;
    public GameObject ImpactBulletEffect;
    public int damageEnemyFromTowerAmount = 30;

    public void Seek(Transform _target)
    {
        target = _target;
    }
	
	void Update () {
        if (target == null)
        {
            Destroy(gameObject);
            return;
        }
        Vector3 dir = target.position - transform.position;
        float distanceThisFrame = speed * Time.deltaTime;

        if (dir.magnitude <= distanceThisFrame)
        {
            HitTarget();
            return;
        }
        transform.Translate (dir.normalized * distanceThisFrame, Space.World);
	}

    

    void HitTarget()
    {
        GameObject effectIns = (GameObject)Instantiate(ImpactBulletEffect, transform.position, transform.rotation);
        Destroy(effectIns, 1f);
        Destroy(gameObject);
        Damage(target);
    }

    void Damage(Transform enemy)
    {  // Function for calling the GameObject found & damaging "enemies" appoximately to the public variable
        Enemy e = enemy.GetComponent<Enemy>();
        if (e != null)
        {
            e.DamageEnemy(damageEnemyFromTowerAmount);
        }
        //Destroy(enemy.gameObject);
    } 
}
