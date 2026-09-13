using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;
using UnityEngine.UI;

public class GameMaster : MonoBehaviour {

    public static GameMaster gm;
    [SerializeField]
    private int maxLives = 3;

    [SerializeField]
    private GameObject PauseMenuObject,PauseButton, WeaponSwitch;
    GameObject[] ControlButtons;
    public static bool pausedGame = false;

    public Transform playerPrefab;
    public Transform spawnPoint;
    public int spawnDelay = 2;
    public Transform spawnPrefab;
    [SerializeField]
    private GameObject GameOverUI;
    
    private static int _remainingLives;
    public static int RemainingLives
    {
        get { return _remainingLives; }
    }

    private GameObject minimapObjects;

    void Start()
    {
        _remainingLives = maxLives;
    }

    void Awake()
    {
        pausedGame = false;
        if (gm == null) {
            gm = GameObject.FindGameObjectWithTag("GM").GetComponent<GameMaster>();
        }
        minimapObjects = GameObject.Find("Player");
        minimapObjects.transform.Find("MinimapIcon").gameObject.SetActive(true);
        minimapObjects = GameObject.FindGameObjectWithTag("Enemies");
        minimapObjects.transform.Find("MinimapIcon").gameObject.SetActive(true);
        minimapObjects = GameObject.FindGameObjectWithTag("Allies");
        minimapObjects.transform.Find("MinimapIcon").gameObject.SetActive(true);
        minimapObjects = GameObject.Find("Tower");
        minimapObjects.transform.Find("MinimapIcon").gameObject.SetActive(true);
        minimapObjects = GameObject.Find("EnemyTower");
        minimapObjects.transform.Find("MinimapIcon").gameObject.SetActive(true);
        minimapObjects = GameObject.Find("Base");
        minimapObjects.transform.Find("MinimapIcon").gameObject.SetActive(true);
        minimapObjects = GameObject.Find("EnemyBase");
        minimapObjects.transform.Find("MinimapIcon").gameObject.SetActive(true);
        minimapObjects = GameObject.Find("Hell_ground");
        minimapObjects.transform.Find("GroundQuad").gameObject.SetActive(true);
    }

    public void EndGame()
    {
        Debug.Log("GameOver!");
        GameOverUI.SetActive(true);
    }

    public IEnumerator RespawnPlayer()
    {
        //Debug.Log("audio");
        yield return new WaitForSeconds(spawnDelay);
        Instantiate(playerPrefab, spawnPoint.position, spawnPoint.rotation);
    }

    private StatusIndicator statusindicator;
    public static void KillPlayer(Player player){ 
        Destroy(player.gameObject);
        _remainingLives -= 1;
        if (_remainingLives <= 0)
        {
            gm.EndGame();
        }
        else
        {
            gm.StartCoroutine(gm.RespawnPlayer());
        }
    }

    public static void DestroyTower(Tower tower)
    {
        Destroy(tower.gameObject);
    }

    public void GoToMainMenu()
    {
        Time.timeScale = 1;
        SceneManager.LoadScene("MainMenu");
    }

    void Update()
    {
        if (pausedGame == false)
        {
            Resume();
        }
        else
        {
            PauseGame();
        }
    }

    public void Resume()
    {
        Time.timeScale = 1;
        PauseMenuObject.SetActive(false);
        pausedGame = false;
        PauseButton.GetComponent<Button>().interactable = true;
        ControlButtons = GameObject.FindGameObjectsWithTag("ControlButtons");
        foreach (GameObject controlbut in ControlButtons)
        {
            controlbut.GetComponent<Button>().interactable = true;
        }
    }

    public void PauseGame()
    {
        PauseMenuObject.SetActive(true);
        Time.timeScale = 0;
        pausedGame = true;
        PauseButton.GetComponent<Button>().interactable = false;
        ControlButtons = GameObject.FindGameObjectsWithTag("ControlButtons");
        foreach(GameObject controlbut in ControlButtons)
        {
            controlbut.GetComponent<Button>().interactable = false;
        }
    }
    
    public static void DestroyEnemyTower(EnemyTower enemytower)
    {
        Destroy(enemytower.gameObject);
        PlayerMoney.money += 200;
    }

    public static void KillEnemy(Enemy enemy)
    {
        Destroy(enemy.gameObject);
        PlayerMoney.money += 100;
    }

    public static void KillAlly(Allies ally)
    {
        Destroy(ally.gameObject);
    }

    public static void DestroyBase(Base base1)
    {
        Destroy(base1.gameObject);
        gm.EndGame();
    }

    public static void DestroyEnemyBase(EnemyBase e_base)
    {
        Destroy(e_base.gameObject);
    }
}
