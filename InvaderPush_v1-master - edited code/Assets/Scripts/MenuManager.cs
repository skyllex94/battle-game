using UnityEngine;
using UnityEngine.SceneManagement;

public class MenuManager : MonoBehaviour {

    [SerializeField]
    Scene sceneToLoad;

    void Start()
    {
        Time.timeScale = 1;
    }

	public void StartGame () {
        SceneManager.LoadScene("MapLevels");
	}

    public void QuitGame()
    {
        Debug.Log("Game Quited!");
        Application.Quit();
    }
}
