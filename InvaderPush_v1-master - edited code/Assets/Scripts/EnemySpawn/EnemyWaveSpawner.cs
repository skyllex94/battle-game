using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class EnemyWaveSpawner : MonoBehaviour {

    public enum SpawnState {Spawning, Waiting, Counting};
    [SerializeField]
    private GameObject PauseMenu;
    public bool activePauseMenu;

    [System.Serializable]
    public class Wave
    {
        public string name;
        public Transform enemy;
        public int count;
        public float rate;
    }

    public Wave[] waves;
    private int nextWave = 0;

    public Transform[] spawnPoints;

    public float timeBetweenWaves = 5f;
    public float waveCountdown;


    private float searchCountdown = 1f;

    private SpawnState state = SpawnState.Counting;

    void Start()
    {
        waveCountdown = timeBetweenWaves;
    }

    void Update()
    {
        if (GameObject.FindGameObjectWithTag("PauseMenu") == true)
        {
            return;
        }
            
        if (state == SpawnState.Waiting)
        {
            if (!EnemyIsAlive())
            {
                WaveCompleted();
            }
            else
            {
                return;
            }
        }
        if (waveCountdown <= 0 )
        {
            if (state != SpawnState.Spawning)
            {
                StartCoroutine(SpawnWave(waves[nextWave]));
            }
        }
        else
        {
             waveCountdown -= Time.deltaTime;
        }
    }

    bool EnemyIsAlive()
    {
        searchCountdown -= Time.deltaTime;
        if (searchCountdown <= 0f)
        {
            searchCountdown = 1f;
            if (GameObject.FindGameObjectWithTag("Enemies") == null)
            {
                return false;
            }
        }
        return true;
    }

    public IEnumerator SpawnWave(Wave _wave)
    {
        state = SpawnState.Spawning;
        for (int i = 0; i < _wave.count; i++)
        {
            if (GameObject.FindGameObjectWithTag("PauseMenu") == true)
            {
                Time.timeScale = 0;
            }
            else
            {
                Time.timeScale = 1;
                SpawnEnemy(_wave.enemy);
                yield return new WaitForSeconds(1f / _wave.rate);
            }
        }
        state = SpawnState.Waiting;
        yield break;
    }

    void SpawnEnemy(Transform _enemy)
    {
        if (spawnPoints.Length == 0)
        {
            Debug.LogError("No spawn points");
        }
        Transform _sp = spawnPoints[Random.Range(0, spawnPoints.Length)];
        Instantiate(_enemy, _sp.position, _sp.rotation);
    }

    void WaveCompleted()
    {
        state = SpawnState.Counting;
        waveCountdown = timeBetweenWaves;

        if (nextWave + 1 > waves.Length - 1)
        {
            nextWave = 0;
        }
        else
        {
            nextWave++;
        }
    }
}
